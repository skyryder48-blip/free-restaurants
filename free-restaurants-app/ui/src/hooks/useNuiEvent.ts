import { useEffect, useRef } from 'react';

type NuiEventCallback<T = unknown> = (data: T) => void;

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
      const { type, data } = e.data;
      if (type === event && savedCallback.current) {
        savedCallback.current(data as T);
      }
    };

    window.addEventListener('message', eventListener);
    return () => window.removeEventListener('message', eventListener);
  }, [event]);
}

export default useNuiEvent;
