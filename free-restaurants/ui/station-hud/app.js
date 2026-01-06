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

const ProgressRing = memo(function ProgressRing({ progress, size = 56 }) {
    const strokeWidth = 3;
    const radius = (size - strokeWidth * 2) / 2;
    const circumference = 2 * Math.PI * radius;
    const offset = calculateStrokeDashoffset(progress || 0, circumference);
    
    return (
        <div className="progress-ring">
            <svg viewBox={`0 0 ${size} ${size}`}>
                <circle
                    className="progress-ring-bg"
                    cx={size / 2}
                    cy={size / 2}
                    r={radius}
                />
                <circle
                    className="progress-ring-fill"
                    cx={size / 2}
                    cy={size / 2}
                    r={radius}
                    style={{
                        strokeDasharray: circumference,
                        strokeDashoffset: offset,
                    }}
                />
            </svg>
        </div>
    );
});

// ============================================================================
// SLOT COMPONENT
// ============================================================================

const Slot = memo(function Slot({ index, data }) {
    const status = data?.status || 'empty';
    const progress = data?.progress || 0;
    const quality = data?.quality || 100;
    const playerName = data?.playerName;
    const timeRemaining = data?.timeRemaining;
    
    const showProgress = ['cooking', 'warning'].includes(status);
    const showQuality = ['cooking', 'ready', 'warning'].includes(status) && quality < 100;
    const showTimer = showProgress && timeRemaining > 0;
    const showPlayer = status === 'occupied' && playerName;
    
    return (
        <div className={`slot ${status}`}>
            <span className="slot-number">{index}</span>
            
            {showProgress && <ProgressRing progress={progress} />}
            
            <span className="slot-icon">
                {STATUS_ICONS[status] || STATUS_ICONS.empty}
            </span>
            
            {showTimer && (
                <span className="slot-timer">{formatTime(timeRemaining)}</span>
            )}
            
            {showQuality && (
                <div className={`quality-indicator ${getQualityClass(quality)}`} />
            )}
            
            {showPlayer && (
                <span className="slot-player">{playerName}</span>
            )}
        </div>
    );
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
    const stationIcon = useMemo(() => {
        return STATION_ICONS[stationType] || STATION_ICONS.default;
    }, [stationType]);
    
    // Get station display name
    const stationName = useMemo(() => {
        if (!stationType) return 'Station';
        return stationType
            .split('_')
            .map(word => word.charAt(0).toUpperCase() + word.slice(1))
            .join(' ');
    }, [stationType]);
    
    // Generate slot array
    const slotArray = useMemo(() => {
        const arr = [];
        for (let i = 1; i <= capacity; i++) {
            arr.push({
                index: i,
                data: slots[i] || { status: 'empty' },
            });
        }
        return arr;
    }, [capacity, slots]);
    
    // Handle NUI messages
    useEffect(() => {
        const handleMessage = (event) => {
            const { type, data } = event.data;
            
            switch (type) {
                case 'showStationHUD':
                    setStationKey(data.stationKey || '');
                    setStationType(data.stationType || '');
                    setCapacity(data.capacity || 1);
                    setSlots(data.slots || {});
                    setVisible(true);
                    break;
                    
                case 'hideStationHUD':
                    setVisible(false);
                    break;
                    
                case 'updateSlots':
                    if (data.stationKey === stationKey || !stationKey) {
                        setSlots(data.slots || {});
                    }
                    break;
                    
                default:
                    break;
            }
        };
        
        window.addEventListener('message', handleMessage);
        return () => window.removeEventListener('message', handleMessage);
    }, [stationKey]);
    
    // Handle ESC key to close
    useEffect(() => {
        const handleKeyDown = (event) => {
            if (event.key === 'Escape' && visible) {
                // Send close message to Lua
                fetch(`https://${GetParentResourceName()}/closeHUD`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({}),
                }).catch(() => {});
                setVisible(false);
            }
        };
        
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [visible]);
    
    return (
        <div className={`station-hud ${visible ? 'visible' : 'hidden'}`}>
            <div className="station-header">
                <span className="station-icon">{stationIcon}</span>
                <span className="station-name">{stationName}</span>
            </div>
            
            <div className="slots-container">
                {slotArray.map(({ index, data }) => (
                    <Slot key={index} index={index} data={data} />
                ))}
            </div>
            
            <div className="close-hint">
                Press <kbd>ESC</kbd> to close
            </div>
        </div>
    );
}

// ============================================================================
// RENDER APPLICATION
// ============================================================================

const root = ReactDOM.createRoot(document.getElementById('station-hud-root'));
root.render(React.createElement(StationHUD));

// ============================================================================
// NUI CALLBACK HANDLER
// ============================================================================

// Helper function to get parent resource name
function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'free-restaurants';
}
