$("table:not([class~='table'])").addClass("table table-striped");

var shiftWindow = function() { scrollBy(0, -70) };
window.addEventListener("hashchange", shiftWindow);
window.setTimeout( shiftWindow , .1);

