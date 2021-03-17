refresh_handler = function(e) {
    var elements = document.querySelectorAll("*[realsrc]");

    for (var i = 0; i < elements.length; i++) {
        var boundingClientRect = elements[i].getBoundingClientRect();
        if (elements[i].hasAttribute("realsrc") && boundingClientRect.top < window.innerHeight*3) {
            elements[i].setAttribute("src", elements[i].getAttribute("realsrc"));
            elements[i].removeAttribute("realsrc");
        }
    }

    var page = document.getElementById("page");
    var pageRect = page.getBoundingClientRect();
    var elements = document.querySelectorAll("img[src]");

};

window.addEventListener('scroll', refresh_handler);
window.addEventListener('load', refresh_handler);
window.addEventListener('resize', refresh_handler);
