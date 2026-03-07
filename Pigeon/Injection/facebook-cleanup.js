(function() {
    'use strict';

    // === DOM CLEANUP via MutationObserver ===
    const SELECTORS_TO_REMOVE = [
        '[data-testid="reels_surface"]',
        '[data-testid="pymk"]',
        '[data-testid="messenger_ad"]',
        '.notificationContainer:not([data-messenger])',
    ];

    const observer = new MutationObserver((mutations) => {
        for (const selector of SELECTORS_TO_REMOVE) {
            document.querySelectorAll(selector).forEach(el => el.remove());
        }
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    // === EXTERNAL LINK INTERCEPTION ===
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
