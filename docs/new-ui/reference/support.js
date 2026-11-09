// Local stand-in for the canvas runtime (the canvas serves its own `support.js` beside each
// board). The boards are static HTML/CSS, so all this needs to do is move each <helmet>
// (font links, page styles) into <head> and let <x-dc> lay out as a block.
//
// It also points the board fonts at the SAME font files the app bundles
// (assets/fonts/), so a board render and an app golden are drawn from identical glyphs.
(function () {
  var fonts = '../../../assets/fonts/';
  var css =
    'x-dc{display:block} helmet{display:none}' +
    "@font-face{font-family:'Geist';font-weight:400;src:url('" + fonts + "Geist-Regular.ttf')}" +
    "@font-face{font-family:'Geist';font-weight:500;src:url('" + fonts + "Geist-Medium.ttf')}" +
    "@font-face{font-family:'Geist Mono';font-weight:400;src:url('" + fonts + "GeistMono-Regular.ttf')}" +
    "@font-face{font-family:'Geist Mono';font-weight:500;src:url('" + fonts + "GeistMono-Medium.ttf')}" +
    "@font-face{font-family:'Outfit';font-weight:100 900;src:url('" + fonts + "Outfit-VariableFont_wght.ttf')}";
  var style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);
  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('helmet').forEach(function (h) {
      while (h.firstChild) document.head.appendChild(h.firstChild);
      h.remove();
    });
  });
})();
