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
  
  // We'll define the assets array
  const games = [
    { id: 1, title: 'Cyber Drift', img: 'thumb_cyberpunk_racing_1776402685155.png' },
    { id: 2, title: 'Crystal Quest', img: 'thumb_retro_rpg_1776402698058.png' },
    { id: 3, title: 'Iron Fists', img: 'thumb_fighting_game_1776402711977.png' },
    { id: 4, title: 'Star Explorer', img: 'hero_scifi_game_1776402674256.png' }
  ];

  // Set Hero Background dynamically based on local assets
  const heroSection = document.getElementById('hero');
  heroSection.style.backgroundImage = `url('/assets/hero_scifi_game_1776402674256.png')`;

  // Populate carousels
  populateCarousel('carousel-recent');
  populateCarousel('carousel-trending', [...games].reverse());

  function populateCarousel(containerId, sourceGames = games) {
    const container = document.getElementById(containerId);
    
    for (let i = 0; i < 8; i++) {
      const game = sourceGames[i % sourceGames.length];
      
      const card = document.createElement('div');
      card.className = 'game-card';
      card.onclick = () => alert(`Starting ${game.title} via RetroArch... (Mock Concept)`);
      
      const img = document.createElement('img');
      img.alt = game.title;
      img.src = `/assets/${game.img}`;
      
      card.appendChild(img);
      container.appendChild(card);
    }
  }

});

function playMockGame() {
  alert("Launching 'Star Explorer' in Emulation Core! (Mock Concept)");
}
