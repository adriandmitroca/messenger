(function() {
    'use strict';

    // Open external links in the system browser
    document.addEventListener('click', (e) => {
        const anchor = e.target.closest('a[href]');
        if (!anchor) return;

        const href = anchor.href;
        const isMessengerLink = href.includes('facebook.com/messages')
            || href.includes('messenger.com')
            || href.startsWith('#')
            || href.startsWith('javascript:');

        if (!isMessengerLink && href.startsWith('http')) {
            e.preventDefault();
            e.stopPropagation();
            window.webkit.messageHandlers.externalLink.postMessage(href);
        }
    }, true);
})();
