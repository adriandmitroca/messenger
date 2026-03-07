(function() {
    'use strict';

    // === INTERCEPT BROWSER NOTIFICATIONS ===
    if (!window.__messengerNotificationBridgeInstalled) {
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
    }

    // === UNREAD COUNT OBSERVER ===
    // Clean up previous instance if re-injected
    if (window.__messengerUnreadInterval) {
        clearInterval(window.__messengerUnreadInterval);
    }
    if (window.__messengerThreadObserver) {
        window.__messengerThreadObserver.disconnect();
    }

    let lastCount = -1;

    function countUnreadConversations() {
        let count = 0;
        const rows = document.querySelectorAll('[role="row"]');
        for (const row of rows) {
            const spans = row.querySelectorAll('span[dir="auto"]');
            if (spans.length < 2) continue;
            // Unread conversations have bold (fontWeight >= 600) message preview
            const weight = parseInt(getComputedStyle(spans[1]).fontWeight, 10);
            if (weight >= 600) count++;
        }
        return count;
    }

    function sendUnreadCount() {
        const count = countUnreadConversations();
        if (count !== lastCount) {
            lastCount = count;
            window.webkit.messageHandlers.unreadCount.postMessage(count);
        }
    }

    let debounceTimer = null;
    function debouncedSendUnreadCount() {
        if (debounceTimer) clearTimeout(debounceTimer);
        debounceTimer = setTimeout(sendUnreadCount, 500);
    }

    // Watch thread list for DOM changes (new messages, read state changes)
    const threadList = document.querySelector('[aria-label="Thread list"]');
    if (threadList) {
        const threadObserver = new MutationObserver(debouncedSendUnreadCount);
        window.__messengerThreadObserver = threadObserver;
        threadObserver.observe(threadList, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['class'],
        });
    }

    // Send immediately, then poll as fallback
    sendUnreadCount();
    window.__messengerUnreadInterval = setInterval(sendUnreadCount, 5000);
    window.__messengerNotificationBridgeInstalled = true;
})();
