import { useCallback, useState } from 'react'
import { useHubStore } from '../../state/hub-store'
import { useT } from '../../i18n'
import { Popover } from '../common/Popover'
import { HubDialogs } from './HubDialogs'
import styles from './HubDialogs.module.css'

export function HubGroupMenu({ titleClassName }: { titleClassName?: string }) {
  const t = useT()
  const count = useHubStore((s) => s.hubs.filter((hub) => hub.online).length)
  const [open, setOpen] = useState(false)
  const close = useCallback(() => setOpen(false), [])
  return (
    <div className={styles.menuRoot}>
      <div className={styles.groupHeading}>
        <h2 className={titleClassName}>{t('sidebar.groups.hub')}</h2>
        <button
          type="button"
          aria-label={t('hub.groupMenu', { count })}
          aria-expanded={open}
          onClick={() => setOpen(!open)}
        >
          {count} · {t('hub.menu')}
        </button>
      </div>
      {open && (
        <Popover label={t('hub.title')} onClose={close}>
          {(['clone', 'manual', 'host'] as const).map((dialog) => (
            <button
              type="button"
              key={dialog}
              onClick={() => {
                close()
                useHubStore.getState().open(dialog)
              }}
            >
              {t(
                dialog === 'clone'
                  ? 'hub.clone'
                  : dialog === 'manual'
                    ? 'hub.addManual'
                    : 'hub.host'
              )}
            </button>
          ))}
        </Popover>
      )}
      <HubDialogs />
    </div>
  )
}
