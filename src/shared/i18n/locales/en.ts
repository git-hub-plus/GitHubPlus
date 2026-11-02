import type { Translations } from '../index'

export const en: Translations = {
  app: {
    name: 'GitHub+',
  },
  menu: {
    file: '&File',
    addRepository: '&Add local repository…',
    createRepository: '&New repository…',
    cloneRepository: '&Clone repository…',
    preferences: '&Preferences…',
    quit: 'E&xit',
    edit: '&Edit',
    undo: '&Undo',
    redo: '&Redo',
    cut: 'Cu&t',
    copy: '&Copy',
    paste: '&Paste',
    selectAll: 'Select &all',
    view: '&View',
    showChanges: '&Changes',
    showHistory: '&History',
    commandPalette: 'Command palette…',
    toggleFullScreen: 'Toggle &full screen',
    reload: '&Reload',
    toggleDevTools: 'Toggle &developer tools',
    repository: '&Repository',
    fetch: '&Fetch',
    pull: 'Pu&ll',
    push: '&Push',
    branch: '&Branch',
    newBranch: '&New branch…',
    help: '&Help',
    reportIssue: 'Report &issue…',
    about: '&About GitHub+',
  },
  sidebar: {
    title: 'Repositories',
    groups: {
      local: 'Local',
      hub: 'Hub',
      github: 'GitHub',
    },
    filterPlaceholder: 'Filter repositories',
    add: 'Add repository',
    empty: 'No repositories yet. Add or clone one.',
    unavailable: 'Missing',
  },
  toolbar: {
    branch: 'Branch',
    noBranch: 'No branch',
    fetch: 'Fetch',
    pull: 'Pull {count}',
    push: 'Push {count}',
    publish: 'Publish',
    hubConnected: 'Hub connected',
    hubOffline: 'Hub offline',
  },
  workspace: {
    changes: 'Changes',
    history: 'History',
    noRepository: 'Select a repository on the left.',
  },
  // U1 (changes view) adds its keys here.
  changesView: {
    title: 'Changes view',
  },
  common: {
    ok: 'OK',
    cancel: 'Cancel',
    close: 'Close',
    save: 'Save',
    retry: 'Retry',
    loading: 'Loading…',
    details: 'Details',
  },
  // U2 (history view) adds its keys here.
  historyView: {
    title: 'History view',
  },
  preferences: {
    title: 'Preferences',
    language: '언어 / Language',
    theme: 'Theme',
    themes: {
      light: 'Light',
      dark: 'Dark',
      system: 'System',
    },
  },
  // U3 (toolbar, branches, sync, dialogs) adds its keys here.
  repoActions: {
    title: 'Repository actions',
  },
  errors: {
    generic: 'The operation could not be completed.',
    notARepository: '{path} is not a Git repository.',
  },
}
