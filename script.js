// EmuBoard Main Logic

// Wait for DOM
document.addEventListener('DOMContentLoaded', () => {

  // Navbar Scroll Effect
  const navbar = document.getElementById('navbar');
  window.addEventListener('scroll', () => {
    if (window.scrollY > 50) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
  });

  // Set Hero Background dynamically based on local assets
  const heroSection = document.getElementById('hero');

  // Fetch real games from our new Node.js backend
  fetch('/api/games')
    .then(res => res.json())
    .then(games => {
      // Remove mock generation logic, strictly use backend img path
      const activeGames = games.filter(g => g.img); // Optional: filter games that don't have thumbnails

      // Default the hero text to the first game
      if(activeGames.length > 0) {
          featureGame(activeGames[0]);
      }

      // Populate Carousels
      populateCarousel('carousel-recent', activeGames);
      populateCarousel('carousel-trending', [...activeGames].reverse());
    })
    .catch(err => {
      console.error("Failed to load games from backend", err);
    });

  function featureGame(game) {
      const heroTitle = document.querySelector('.hero-title');
      heroTitle.textContent = game.title;
      
      const heroSection = document.getElementById('hero');
      heroSection.style.backgroundImage = `url('${game.img}')`;
      heroSection.style.backgroundSize = 'cover';
      heroSection.style.backgroundPosition = 'top center';
      
      const heroDesc = document.querySelector('.hero-desc');
      if (heroDesc) {
         heroDesc.textContent = `Get ready to play ${game.title}! Dive back into this classic retro masterpiece straight from your local library.`;
      }
      
      window.playMockGame = function() {
          launchNativeGame(game.path, game.title);
      };
      
      // Scroll to top smoothly so the user sees the featured game
      window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function populateCarousel(containerId, sourceGames) {
    const container = document.getElementById(containerId);
    
    // Create elements for all real games
    sourceGames.forEach(game => {
      const card = document.createElement('div');
      card.className = 'game-card';
      
      // Instead of firing up openemu immediately, feature it up top!
      card.onclick = () => featureGame(game);
      
      const img = document.createElement('img');
      img.alt = game.title;
      img.src = game.img;
      
      card.appendChild(img);
      container.appendChild(card);
    });
  }

});

// No changes needed, but I'll write the unchanged content just to satisfy the tool call.
function launchNativeGame(romPath, title) {
  alert(`Firing up ${title} in OpenEmu Core!`);
  
  fetch('/api/launch', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ path: romPath })
  })
  .then(res => res.json())
  .then(data => {
      console.log("Launch response:", data);
  })
  .catch(err => {
      console.error("Error launching native game", err);
  });
}
