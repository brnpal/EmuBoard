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

  // Since we copied generated assets into local assets/ folder, let's grab them.
  // The run_command copied *.png. Let's find dynamically what they are named...
  // Alternatively, we know the prefix of the gen images or we can hardcode fallback logic if they change names.
  
  const placeholders = [
    'thumb_cyberpunk_racing_1776402685155.png',
    'thumb_retro_rpg_1776402698058.png',
    'thumb_fighting_game_1776402711977.png',
    'hero_scifi_game_1776402674256.png'
  ];

  // Set Hero Background dynamically based on local assets
  const heroSection = document.getElementById('hero');
  heroSection.style.backgroundImage = `url('/assets/hero_scifi_game_1776402674256.png')`;

  // Fetch real games from our new Node.js backend
  fetch('/api/games')
    .then(res => res.json())
    .then(games => {
      // Inject some mock thumbnails ONLY if we didn't get real boxart scraped!
      const gamesWithImages = games.map((g, index) => {
         return {
            ...g,
            img: g.img || `/assets/${placeholders[index % placeholders.length]}`
         };
      });

      // Update the hero text to standard
      if(gamesWithImages.length > 0) {
          // Let's filter for one that actually has a real boxart to feature it if possible, otherwise use first
          const featured = gamesWithImages.find(g => g.img && !g.img.includes('/assets/')) || gamesWithImages[0];
          
          const heroTitle = document.querySelector('.hero-title');
          heroTitle.textContent = featured.title;
          
          // Use the actual box art as the hero background if it exists
          const heroSection = document.getElementById('hero');
          heroSection.style.backgroundImage = `url('${featured.img}')`;
          // Tweak the css background size to 'contain' if it's a vertical boxart, but keep Netflix feel
          heroSection.style.backgroundSize = 'cover';
          heroSection.style.backgroundPosition = 'top center';
          
          window.playMockGame = function() {
              launchNativeGame(featured.path, featured.title);
          };
      }

      // Populate Carousels
      populateCarousel('carousel-recent', gamesWithImages);
      // Give trending a slightly shuffled view
      populateCarousel('carousel-trending', [...gamesWithImages].reverse());
    })
    .catch(err => {
      console.error("Failed to load games from backend", err);
    });

  function populateCarousel(containerId, sourceGames) {
    const container = document.getElementById(containerId);
    
    // Create elements for all real games
    sourceGames.forEach(game => {
      const card = document.createElement('div');
      card.className = 'game-card';
      // Pass the real native rom path
      card.onclick = () => launchNativeGame(game.path, game.title);
      
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
