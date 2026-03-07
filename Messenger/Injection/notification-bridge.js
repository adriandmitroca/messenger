(function() {
    'use strict';

    // === INTERCEPT BROWSER NOTIFICATIONS ===
    Object.defineProperty(window, 'Notification', {
        value: class FakeNotification {
            static get permission() { return 'granted'; }
            static requestPermission(cb) {
                if (cb) cb('granted');
                return Promise.resolve('granted');
            }

            constructor(title, options = {}) {
                window.webkit.messageHandlers.notificationBridge.postMessage({
                    title: title,
                    body: options.body || '',
                    icon: options.icon || '',
                    tag: options.tag || '',
                    data: options.data || {}
                });

                this._onclick = null;
                this._onclose = null;
            }

            set onclick(fn) { this._onclick = fn; }
            get onclick() { return this._onclick; }
            set onclose(fn) { this._onclose = fn; }
            get onclose() { return this._onclose; }
            close() {}
        },
        writable: false,
        configurable: false
    });

    // === UNREAD COUNT OBSERVER ===
    const titleObserver = new MutationObserver(() => {
        const title = document.title;
        const match = title.match(/\((\d+)\)/);
        const count = match ? parseInt(match[1], 10) : 0;
        window.webkit.messageHandlers.unreadCount.postMessage(count);
    });

    const titleElement = document.querySelector('title');
    if (titleElement) {
        titleObserver.observe(titleElement, { childList: true });
    }

    setInterval(() => {
        const title = document.title;
        const match = title.match(/\((\d+)\)/);
        const count = match ? parseInt(match[1], 10) : 0;
        window.webkit.messageHandlers.unreadCount.postMessage(count);
    }, 5000);
})();
