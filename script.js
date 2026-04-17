// EmuBoard Main Logic

function launchNativeGame(romPath, title, emulator) {
  fetch('/api/launch', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ path: romPath, emulator: emulator })
  })
  .then(res => res.json())
  .then(data => {
      console.log("Launch response:", data);
      // Re-fetch games to update Recently Played after a launch
      refreshGames();
  })
  .catch(err => {
      console.error("Error launching native game", err);
  });
}

function featureGame(game) {
    const heroTitle = document.querySelector('.hero-title');
    heroTitle.textContent = game.title;
    
    const heroSection = document.getElementById('hero');
    heroSection.style.backgroundImage = `url('${game.img}')`;
    heroSection.style.backgroundSize = 'cover';
    heroSection.style.backgroundPosition = 'center center';
    
    const heroDesc = document.querySelector('.hero-desc');
    if (heroDesc) {
       heroDesc.textContent = `Get ready to play ${game.title}! Dive back into this classic retro masterpiece straight from your local library.`;
    }
    
    window.playMockGame = function() {
        launchNativeGame(game.path, game.title, game.emulator);
    };
    
    // Scroll to top smoothly so the user sees the featured game
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

function populateCarousel(containerId, sourceGames) {
  const container = document.getElementById(containerId);
  container.innerHTML = ''; // clear existing contents
  
  sourceGames.forEach(game => {
    const card = document.createElement('div');
    card.className = 'game-card';
    
    card.onclick = () => launchNativeGame(game.path, game.title, game.emulator);
    
    if (game.img) {
        const img = document.createElement('img');
        img.alt = game.title;
        img.src = game.img;
        card.appendChild(img);
    } else {
        const titleDiv = document.createElement('div');
        titleDiv.className = 'game-card-title';
        titleDiv.textContent = game.title;
        card.appendChild(titleDiv);
        card.classList.add('no-img');
    }
    
    container.appendChild(card);
  });
}

function refreshGames(isInitialLoad = false) {
  fetch('/api/games')
    .then(res => res.json())
    .then(games => {
      // Include all games
      const activeGames = games;

      // 1. Sort games alphabetically for A-Z
      const azGames = [...activeGames].sort((a, b) => a.title.localeCompare(b.title));
      
      // 2. Real 'Recently Played'
      const recentGames = [...activeGames]
          .filter(g => g.lastPlayed > 0)
          .sort((a, b) => b.lastPlayed - a.lastPlayed)
          .slice(0, 10);

      // Default the hero to the most recently played game, or the first A-Z game
      if (recentGames.length > 0) {
          featureGame(recentGames[0]);
      } else if (isInitialLoad && azGames.length > 0) {
          featureGame(azGames[0]);
      }

      // Populate containers
      populateCarousel('carousel-recent', recentGames);
      populateCarousel('grid-az', azGames);
    })
    .catch(err => {
      console.error("Failed to load games from backend", err);
    });
}

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

  // Initial fetch of games
  refreshGames(true);

  // Setup scroll arrow logic for recently played
  const scrollRightBtn = document.getElementById('scroll-right-recent');
  const recentContainer = document.getElementById('carousel-recent');
  if (scrollRightBtn && recentContainer) {
      scrollRightBtn.addEventListener('click', () => {
          // Scroll horizontally by roughly 3-4 cards
          recentContainer.scrollBy({ left: 800, behavior: 'smooth' });
      });
  }
});
