/**
 * Station HUD Application
 * Clean, modern React-based HUD for cooking station slots
 *
 * Features:
 * - Shows slot status (empty, preparing, cooking, ready, warning, burnt)
 * - Circular progress indicators
 * - Quality indicators
 * - Timer display
 * - Player name for occupied slots
 */

const { useState, useEffect, useCallback, useMemo, memo } = React;
const h = React.createElement;

// ============================================================================
// CONSTANTS
// ============================================================================

const STATION_ICONS = {
    grill: '🔥',
    fryer: '🍟',
    oven: '🔥',
    stovetop: '🍳',
    prep_counter: '🔪',
    cutting_board: '🔪',
    mixer: '🥣',
    coffee_machine: '☕',
    drink_mixer: '🍸',
    pizza_oven: '🍕',
    ice_cream_machine: '🍦',
    soda_fountain: '🥤',
    blender: '🥤',
    plating_station: '🍽️',
    packaging_station: '📦',
    default: '👨‍🍳',
};

const STATUS_ICONS = {
    empty: '○',
    preparing: '◐',
    cooking: '◉',
    ready: '✓',
    warning: '⚠',
    burnt: '✕',
    occupied: '●',
};

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Format seconds to MM:SS display
 */
function formatTime(seconds) {
    if (!seconds || seconds < 0) return '';
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return mins > 0 ? `${mins}:${secs.toString().padStart(2, '0')}` : `${secs}s`;
}

/**
 * Get quality class from percentage
 */
function getQualityClass(quality) {
    if (quality >= 90) return 'excellent';
    if (quality >= 75) return 'good';
    if (quality >= 50) return 'average';
    if (quality >= 25) return 'poor';
    return 'terrible';
}

/**
 * Calculate progress ring stroke-dashoffset
 */
function calculateStrokeDashoffset(progress, circumference) {
    return circumference - (progress / 100) * circumference;
}

// ============================================================================
// PROGRESS RING COMPONENT
// ============================================================================

const ProgressRing = memo(function ProgressRing(props) {
    const progress = props.progress;
    const size = props.size || 56;
    const strokeWidth = 3;
    const radius = (size - strokeWidth * 2) / 2;
    const circumference = 2 * Math.PI * radius;
    const offset = calculateStrokeDashoffset(progress || 0, circumference);

    return h('div', { className: 'progress-ring' },
        h('svg', { viewBox: `0 0 ${size} ${size}` },
            h('circle', {
                className: 'progress-ring-bg',
                cx: size / 2,
                cy: size / 2,
                r: radius
            }),
            h('circle', {
                className: 'progress-ring-fill',
                cx: size / 2,
                cy: size / 2,
                r: radius,
                style: {
                    strokeDasharray: circumference,
                    strokeDashoffset: offset
                }
            })
        )
    );
});

// ============================================================================
// SLOT COMPONENT
// ============================================================================

const Slot = memo(function Slot(props) {
    const index = props.index;
    const data = props.data;
    const status = (data && data.status) || 'empty';
    const progress = (data && data.progress) || 0;
    const quality = (data && data.quality) || 100;
    const playerName = data && data.playerName;
    const timeRemaining = data && data.timeRemaining;

    const showProgress = ['cooking', 'warning'].includes(status);
    const showQuality = ['cooking', 'ready', 'warning'].includes(status) && quality < 100;
    const showTimer = showProgress && timeRemaining > 0;
    const showPlayer = status === 'occupied' && playerName;

    const children = [
        h('span', { className: 'slot-number', key: 'num' }, index)
    ];

    if (showProgress) {
        children.push(h(ProgressRing, { progress: progress, key: 'progress' }));
    }

    children.push(
        h('span', { className: 'slot-icon', key: 'icon' },
            STATUS_ICONS[status] || STATUS_ICONS.empty
        )
    );

    if (showTimer) {
        children.push(
            h('span', { className: 'slot-timer', key: 'timer' }, formatTime(timeRemaining))
        );
    }

    if (showQuality) {
        children.push(
            h('div', { className: `quality-indicator ${getQualityClass(quality)}`, key: 'quality' })
        );
    }

    if (showPlayer) {
        children.push(
            h('span', { className: 'slot-player', key: 'player' }, playerName)
        );
    }

    return h('div', { className: `slot ${status}` }, children);
});

// ============================================================================
// MAIN HUD COMPONENT
// ============================================================================

function StationHUD() {
    const [visible, setVisible] = useState(false);
    const [stationKey, setStationKey] = useState('');
    const [stationType, setStationType] = useState('');
    const [capacity, setCapacity] = useState(1);
    const [slots, setSlots] = useState({});

    // Get station icon
    const stationIcon = useMemo(function() {
        return STATION_ICONS[stationType] || STATION_ICONS.default;
    }, [stationType]);

    // Get station display name
    const stationName = useMemo(function() {
        if (!stationType) return 'Station';
        return stationType
            .split('_')
            .map(function(word) { return word.charAt(0).toUpperCase() + word.slice(1); })
            .join(' ');
    }, [stationType]);

    // Generate slot array
    const slotArray = useMemo(function() {
        const arr = [];
        for (let i = 1; i <= capacity; i++) {
            arr.push({
                index: i,
                data: slots[i] || { status: 'empty' }
            });
        }
        return arr;
    }, [capacity, slots]);

    // Handle NUI messages
    useEffect(function() {
        const handleMessage = function(event) {
            const type = event.data.type;
            const data = event.data.data;

            switch (type) {
                case 'showStationHUD':
                    setStationKey((data && data.stationKey) || '');
                    setStationType((data && data.stationType) || '');
                    setCapacity((data && data.capacity) || 1);
                    setSlots((data && data.slots) || {});
                    setVisible(true);
                    break;

                case 'hideStationHUD':
                    setVisible(false);
                    break;

                case 'updateSlots':
                    if ((data && data.stationKey) === stationKey || !stationKey) {
                        setSlots((data && data.slots) || {});
                    }
                    break;
            }
        };

        window.addEventListener('message', handleMessage);
        return function() { window.removeEventListener('message', handleMessage); };
    }, [stationKey]);

    // Handle ESC key to close
    useEffect(function() {
        const handleKeyDown = function(event) {
            if (event.key === 'Escape' && visible) {
                // Send close message to Lua
                fetch(`https://${GetParentResourceName()}/closeHUD`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({})
                }).catch(function() {});
                setVisible(false);
            }
        };

        window.addEventListener('keydown', handleKeyDown);
        return function() { window.removeEventListener('keydown', handleKeyDown); };
    }, [visible]);

    // Build slot elements
    const slotElements = slotArray.map(function(item) {
        return h(Slot, { key: item.index, index: item.index, data: item.data });
    });

    return h('div', { className: `station-hud ${visible ? 'visible' : 'hidden'}` },
        h('div', { className: 'station-header' },
            h('span', { className: 'station-icon' }, stationIcon),
            h('span', { className: 'station-name' }, stationName)
        ),
        h('div', { className: 'slots-container' }, slotElements),
        h('div', { className: 'close-hint' },
            'Press ',
            h('kbd', null, 'ESC'),
            ' to close'
        )
    );
}

// ============================================================================
// RENDER APPLICATION
// ============================================================================

const root = ReactDOM.createRoot(document.getElementById('station-hud-root'));
root.render(h(StationHUD));

// ============================================================================
// NUI CALLBACK HANDLER
// ============================================================================

// Helper function to get parent resource name
function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'free-restaurants';
}
