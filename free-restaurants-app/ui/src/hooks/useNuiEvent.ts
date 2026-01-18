import { useEffect, useRef } from 'react';

type NuiEventCallback<T = unknown> = (data: T) => void;

// Debug mode - set to true to log all messages
const DEBUG = true;

export function useNuiEvent<T = unknown>(
  event: string,
  callback: NuiEventCallback<T>
) {
  const savedCallback = useRef<NuiEventCallback<T>>();

  useEffect(() => {
    savedCallback.current = callback;
  }, [callback]);

  useEffect(() => {
    const eventListener = (e: MessageEvent) => {
      // Debug: log all incoming messages
      if (DEBUG) {
        console.log('[Food Hub] Received message:', JSON.stringify(e.data));
      }

      // Handle different message formats
      let messageType: string | undefined;
      let messageData: unknown;

      // Format 1: Direct { type, data } (standard NUI)
      if (e.data && typeof e.data === 'object') {
        if (e.data.type !== undefined) {
          messageType = e.data.type;
          messageData = e.data.data;
        }
        // Format 2: LB Phone might send data directly without wrapper
        // or with action/app wrapper
        else if (e.data.action === 'customAppMessage' && e.data.data) {
          const innerData = e.data.data;
          if (innerData && typeof innerData === 'object' && innerData.type !== undefined) {
            messageType = innerData.type;
            messageData = innerData.data;
          }
        }
      }

      if (DEBUG && messageType) {
        console.log('[Food Hub] Parsed message type:', messageType, 'looking for:', event);
      }

      if (messageType === event && savedCallback.current) {
        if (DEBUG) {
          console.log('[Food Hub] Matched event:', event, 'with data:', messageData);
        }
        savedCallback.current(messageData as T);
      }
    };

    window.addEventListener('message', eventListener);
    return () => window.removeEventListener('message', eventListener);
  }, [event]);
}

export default useNuiEvent;
