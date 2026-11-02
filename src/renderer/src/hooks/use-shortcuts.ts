import { useEffect } from 'react'

export function useShortcuts(): void {
  useEffect(() => {
    const listener = (event: KeyboardEvent) => {
      if (
        (event.ctrlKey || event.metaKey) &&
        event.key.toLowerCase() === 'p' &&
        !event.altKey &&
        !event.shiftKey &&
        !document.querySelector('dialog[open]')
      ) {
        event.preventDefault()
        document.getElementById('repository-search')?.focus()
      }
    }
    window.addEventListener('keydown', listener)
    return () => window.removeEventListener('keydown', listener)
  }, [])
}
