$("table:not([class~='table'])").addClass("table table-striped");

var shiftWindow = function() { scrollBy(0, -70) };
if (location.hash) shiftWindow();
window.addEventListener("hashchange", shiftWindow);
