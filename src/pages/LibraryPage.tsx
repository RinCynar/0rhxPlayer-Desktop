import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { usePlayer, splitArtists } from '../context/PlayerContext';
import { I18N, formatCount } from '../i18n';
import { M3MediaCard } from '../components/M3MediaCard';
import { M3ListItem } from '../components/M3ListItem';
import { M3MediaGrid } from '../components/M3MediaGrid';
import { TrackMetadata } from '../types/audio';
import { TrackActionMenu } from '../components/TrackActionMenu';
import { M3Dropdown, DropdownOption } from '../components/M3Dropdown';

type FilterChip = 'titles' | 'artists' | 'albums' | 'folders';
type ViewMode = 'grid' | 'list';
type SortKey =
  | 'title_asc' | 'title_desc' | 'artist_asc' | 'artist_desc'
  | 'album_asc' | 'album_desc' | 'folder_asc' | 'folder_desc'
  | 'track_count_desc' | 'track_count_asc'
  | 'size_desc' | 'bitrate_desc' | 'format_asc'
  | 'modified_desc' | 'added_desc' | 'duration_desc' | 'duration_asc';

interface FilterGroupDetail {
  type: 'artist' | 'album' | 'folder';
  name: string;
  subTitle?: string;
  coverUrl?: string;
}

export const LibraryPage: React.FC = () => {
  const {
    lang, libraryTracks, playTrack,
    isScanning, scannedCount, scanDirectoryAction, importFilesAction,
    scannedFolders, addScanFolderAction, removeScanFolder, rescanLibraryAction,
    isFavorite, toggleFavorite, removeTracksFromLibrary,
    playlists, createPlaylist, addTrackToPlaylist, addToQueue,
    artistSeparators,
  } = usePlayer();

  const t = I18N[lang];
  const [filterChip, setFilterChip] = useState<FilterChip>('titles');
  const [viewMode, setViewMode] = useState<ViewMode>(() => {
    try {
      const saved = localStorage.getItem('0rhx_library_view_mode');
      return saved === 'list' || saved === 'grid' ? saved : 'grid';
    } catch {
      return 'grid';
    }
  });

  useEffect(() => {
    try {
      localStorage.setItem('0rhx_library_view_mode', viewMode);
    } catch { /* ignore */ }
  }, [viewMode]);

  const [sortKey, setSortKey] = useState<SortKey>('title_asc');
  const [selectedGroup, setSelectedGroup] = useState<FilterGroupDetail | null>(null);

  // Multi-select state
  const [isSelectMode, setIsSelectMode] = useState(false);
  const [selectedPaths, setSelectedPaths] = useState<Set<string>>(new Set());
  const [showBatchPlaylistModal, setShowBatchPlaylistModal] = useState(false);
  const [newPlaylistName, setNewPlaylistName] = useState('');

  // Context menu state
  const [menuTrack, setMenuTrack] = useState<TrackMetadata | null>(null);
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  const card = 'bg-md-surface-container hover:bg-md-surface-container-high shadow-sm';
  const primaryText = 'text-md-primary';
  const primaryBg = 'bg-md-primary-container text-md-on-primary-container';
  const accentButton = 'bg-md-primary text-md-on-primary';

  // 1. Filter tracks based on drill-down group if active
  const baseTracks = useMemo(() => {
    if (!selectedGroup) return libraryTracks;
    switch (selectedGroup.type) {
      case 'artist':
        return libraryTracks.filter(tr => splitArtists(tr.artist, artistSeparators).includes(selectedGroup.name));
      case 'album':
        return libraryTracks.filter(tr => (tr.album || 'Unknown Album') === selectedGroup.name);
      case 'folder': {
        const normGroup = selectedGroup.name.replace(/\\/g, '/').toLowerCase();
        return libraryTracks.filter(tr => {
          const normTrack = tr.path.replace(/\\/g, '/').toLowerCase();
          return normTrack.startsWith(normGroup);
        });
      }
      default:
        return libraryTracks;
    }
  }, [libraryTracks, selectedGroup, artistSeparators]);

  // 2. Sort tracks
  const sortedTracks = useMemo(() => {
    const list = [...baseTracks];
    switch (sortKey) {
      case 'title_asc':
        return list.sort((a, b) => (a.title || '').localeCompare(b.title || '', lang === 'zh' ? 'zh-Hans-CN' : undefined, { sensitivity: 'base' }));
      case 'title_desc':
        return list.sort((a, b) => (b.title || '').localeCompare(a.title || '', lang === 'zh' ? 'zh-Hans-CN' : undefined, { sensitivity: 'base' }));
      case 'artist_asc':
        return list.sort((a, b) => (a.artist || '').localeCompare(b.artist || '', lang === 'zh' ? 'zh-Hans-CN' : undefined, { sensitivity: 'base' }));
      case 'artist_desc':
        return list.sort((a, b) => (b.artist || '').localeCompare(a.artist || '', lang === 'zh' ? 'zh-Hans-CN' : undefined, { sensitivity: 'base' }));
      case 'size_desc':
        return list.sort((a, b) => ((b.bitrate || 1000) * (b.durationMs || 0)) - ((a.bitrate || 1000) * (a.durationMs || 0)));
      case 'bitrate_desc':
        return list.sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));
      case 'format_asc':
        return list.sort((a, b) => (a.format || '').localeCompare(b.format || ''));
      case 'duration_desc':
        return list.sort((a, b) => (b.durationMs || 0) - (a.durationMs || 0));
      case 'duration_asc':
        return list.sort((a, b) => (a.durationMs || 0) - (b.durationMs || 0));
      default:
        return list;
    }
  }, [baseTracks, sortKey, lang]);

  // 3. Aggregations for Artists (Split Pipeline), Albums, Folders
  const artistsList = useMemo(() => {
    const map = new Map<string, { name: string; count: number; coverUrl?: string; tracks: TrackMetadata[] }>();
    for (const tr of libraryTracks) {
      const artistNames = splitArtists(tr.artist, artistSeparators);
      for (const art of artistNames) {
        if (!map.has(art)) {
          map.set(art, { name: art, count: 1, coverUrl: tr.coverUrl, tracks: [tr] });
        } else {
          const item = map.get(art)!;
          item.count += 1;
          item.tracks.push(tr);
          if (!item.coverUrl && tr.coverUrl) item.coverUrl = tr.coverUrl;
        }
      }
    }
    const list = Array.from(map.values());
    if (sortKey === 'artist_desc') {
      return list.sort((a, b) => b.name.localeCompare(a.name, lang === 'zh' ? 'zh-Hans-CN' : undefined));
    }
    if (sortKey === 'track_count_desc') {
      return list.sort((a, b) => b.count - a.count);
    }
    if (sortKey === 'track_count_asc') {
      return list.sort((a, b) => a.count - b.count);
    }
    return list.sort((a, b) => a.name.localeCompare(b.name, lang === 'zh' ? 'zh-Hans-CN' : undefined));
  }, [libraryTracks, artistSeparators, sortKey, lang]);

  const albumsList = useMemo(() => {
    const map = new Map<string, { name: string; artist: string; count: number; coverUrl?: string; tracks: TrackMetadata[] }>();
    for (const tr of libraryTracks) {
      const alb = tr.album && tr.album.trim() ? tr.album.trim() : 'Unknown Album';
      if (!map.has(alb)) {
        map.set(alb, { name: alb, artist: tr.artist || '—', count: 1, coverUrl: tr.coverUrl, tracks: [tr] });
      } else {
        const item = map.get(alb)!;
        item.count += 1;
        item.tracks.push(tr);
        if (!item.coverUrl && tr.coverUrl) item.coverUrl = tr.coverUrl;
      }
    }
    const list = Array.from(map.values());
    if (sortKey === 'album_desc') {
      return list.sort((a, b) => b.name.localeCompare(a.name, lang === 'zh' ? 'zh-Hans-CN' : undefined));
    }
    if (sortKey === 'track_count_desc') {
      return list.sort((a, b) => b.count - a.count);
    }
    if (sortKey === 'track_count_asc') {
      return list.sort((a, b) => a.count - b.count);
    }
    return list.sort((a, b) => a.name.localeCompare(b.name, lang === 'zh' ? 'zh-Hans-CN' : undefined));
  }, [libraryTracks, sortKey, lang]);

  const foldersList = useMemo(() => {
    const map = new Map<string, { folderPath: string; folderName: string; count: number; tracks: TrackMetadata[] }>();
    for (const sf of scannedFolders) {
      const name = sf.split(/[\\/]/).pop() || sf;
      map.set(sf, { folderPath: sf, folderName: name, count: 0, tracks: [] });
    }
    for (const tr of libraryTracks) {
      const dir = tr.path.replace(/[\\/][^\\/]*$/, '');
      const name = dir.split(/[\\/]/).pop() || dir;
      if (!map.has(dir)) {
        map.set(dir, { folderPath: dir, folderName: name, count: 1, tracks: [tr] });
      } else {
        const item = map.get(dir)!;
        item.count += 1;
        item.tracks.push(tr);
      }
    }
    const list = Array.from(map.values());
    if (sortKey === 'folder_desc') {
      return list.sort((a, b) => b.folderName.localeCompare(a.folderName, lang === 'zh' ? 'zh-Hans-CN' : undefined));
    }
    if (sortKey === 'track_count_desc') {
      return list.sort((a, b) => b.count - a.count);
    }
    if (sortKey === 'track_count_asc') {
      return list.sort((a, b) => a.count - b.count);
    }
    return list.sort((a, b) => a.folderName.localeCompare(b.folderName, lang === 'zh' ? 'zh-Hans-CN' : undefined));
  }, [libraryTracks, scannedFolders, sortKey, lang]);


  // Artist detail: Albums + Tracks aggregation (Task 5)
  const artistDetailAlbums = useMemo(() => {
    if (!selectedGroup || selectedGroup.type !== 'artist') return [];
    const map = new Map<string, { name: string; artist: string; count: number; coverUrl?: string; tracks: TrackMetadata[] }>();
    for (const tr of baseTracks) {
      const alb = tr.album && tr.album.trim() ? tr.album.trim() : 'Unknown Album';
      if (!map.has(alb)) {
        map.set(alb, { name: alb, artist: tr.artist || '—', count: 1, coverUrl: tr.coverUrl, tracks: [tr] });
      } else {
        const item = map.get(alb)!;
        item.count += 1;
        item.tracks.push(tr);
        if (!item.coverUrl && tr.coverUrl) item.coverUrl = tr.coverUrl;
      }
    }
    return Array.from(map.values());
  }, [selectedGroup, baseTracks]);

  const isBrowsingAggregate = !selectedGroup && filterChip !== 'titles';

  // Dynamic sort options based on filterChip & context (Task 4)
  const sortOptions = useMemo<DropdownOption<SortKey>[]>(() => {
    if (selectedGroup || filterChip === 'titles') {
      return [
        { value: 'title_asc', label: t.sortTitleAsc, icon: 'fa-arrow-down-a-z' },
        { value: 'title_desc', label: t.sortTitleDesc, icon: 'fa-arrow-up-z-a' },
        { value: 'artist_asc', label: t.sortArtistAsc, icon: 'fa-user' },
        { value: 'artist_desc', label: t.sortArtistDesc, icon: 'fa-user' },
        { value: 'size_desc', label: t.sortSizeDesc, icon: 'fa-hard-drive' },
        { value: 'bitrate_desc', label: t.sortBitrateDesc, icon: 'fa-wave-square' },
        { value: 'format_asc', label: t.sortFormatAsc, icon: 'fa-file-audio' },
        { value: 'duration_desc', label: t.sortDurationDesc, icon: 'fa-clock' },
        { value: 'duration_asc', label: t.sortDurationAsc, icon: 'fa-clock' },
      ];
    }
    if (filterChip === 'artists') {
      return [
        { value: 'artist_asc', label: t.sortArtistAsc, icon: 'fa-arrow-down-a-z' },
        { value: 'artist_desc', label: t.sortArtistDesc, icon: 'fa-arrow-up-z-a' },
        { value: 'track_count_desc', label: t.sortTrackCountDesc, icon: 'fa-arrow-down-9-1' },
        { value: 'track_count_asc', label: t.sortTrackCountAsc, icon: 'fa-arrow-up-1-9' },
      ];
    }
    if (filterChip === 'albums') {
      return [
        { value: 'album_asc', label: t.sortAlbumAsc, icon: 'fa-arrow-down-a-z' },
        { value: 'album_desc', label: t.sortAlbumDesc, icon: 'fa-arrow-up-z-a' },
        { value: 'track_count_desc', label: t.sortTrackCountDesc, icon: 'fa-arrow-down-9-1' },
        { value: 'track_count_asc', label: t.sortTrackCountAsc, icon: 'fa-arrow-up-1-9' },
      ];
    }
    if (filterChip === 'folders') {
      return [
        { value: 'folder_asc', label: t.sortFolderAsc, icon: 'fa-arrow-down-a-z' },
        { value: 'folder_desc', label: t.sortFolderDesc, icon: 'fa-arrow-up-z-a' },
        { value: 'track_count_desc', label: t.sortTrackCountDesc, icon: 'fa-arrow-down-9-1' },
        { value: 'track_count_asc', label: t.sortTrackCountAsc, icon: 'fa-arrow-up-1-9' },
      ];
    }
    return [];
  }, [filterChip, selectedGroup, t]);

  // Keep sortKey aligned with available options across tab switches
  useEffect(() => {
    if (sortOptions.length > 0 && !sortOptions.some(opt => opt.value === sortKey)) {
      setSortKey(sortOptions[0].value);
    }
  }, [sortOptions, sortKey]);

  // Multi-select handlers
  const toggleSelectTrack = useCallback((path: string, e?: React.MouseEvent) => {
    if (e) e.stopPropagation();
    setSelectedPaths(prev => {
      const next = new Set(prev);
      if (next.has(path)) next.delete(path);
      else next.add(path);
      return next;
    });
  }, []);

  const handleSelectAll = useCallback(() => {
    if (selectedPaths.size === sortedTracks.length) {
      setSelectedPaths(new Set());
    } else {
      setSelectedPaths(new Set(sortedTracks.map(tr => tr.path)));
    }
  }, [selectedPaths, sortedTracks]);

  const handleBatchPlay = useCallback(() => {
    const selected = sortedTracks.filter(tr => selectedPaths.has(tr.path));
    if (selected.length > 0) {
      playTrack(selected[0], selected);
    }
  }, [sortedTracks, selectedPaths, playTrack]);

  const handleBatchAddToQueue = useCallback(() => {
    const selected = sortedTracks.filter(tr => selectedPaths.has(tr.path));
    if (selected.length > 0) {
      addToQueue(selected);
      setSelectedPaths(new Set());
      setIsSelectMode(false);
    }
  }, [sortedTracks, selectedPaths, addToQueue]);

  const handleBatchRemoveFromLibrary = useCallback(() => {
    if (selectedPaths.size === 0) return;
    removeTracksFromLibrary(Array.from(selectedPaths));
    setSelectedPaths(new Set());
    setIsSelectMode(false);
  }, [selectedPaths, removeTracksFromLibrary]);

  const handleBatchAddToPlaylist = useCallback((playlistId: string) => {
    for (const p of selectedPaths) {
      addTrackToPlaylist(playlistId, p);
    }
    setShowBatchPlaylistModal(false);
    setSelectedPaths(new Set());
    setIsSelectMode(false);
  }, [selectedPaths, addTrackToPlaylist]);

  const handleCreateAndAddBatch = useCallback(() => {
    if (!newPlaylistName.trim()) return;
    const plId = createPlaylist(newPlaylistName.trim());
    handleBatchAddToPlaylist(plId);
    setNewPlaylistName('');
  }, [newPlaylistName, createPlaylist, handleBatchAddToPlaylist]);

  return (
    <div className="flex flex-col h-full relative">
      {/* Sticky header */}
      <div className="px-8 pt-8 pb-4 shrink-0 bg-md-surface">
        <div className="max-w-7xl mx-auto space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              {selectedGroup && (
                <button
                  onClick={() => setSelectedGroup(null)}
                  className="w-9 h-9 rounded-full bg-black/5 dark:bg-white/5 flex items-center justify-center hover:bg-black/10 dark:hover:bg-white/10 transition"
                  title={t.back}
                >
                  <i className="fa-solid fa-arrow-left text-sm" />
                </button>
              )}
              <div>
                <h1 className="text-3xl font-bold tracking-tight">
                  {selectedGroup ? selectedGroup.name : t.library}
                </h1>
                {selectedGroup && (
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5 font-medium">
                    {selectedGroup.subTitle || formatCount(sortedTracks.length, 'track', lang)}
                  </p>
                )}
              </div>
            </div>

            <div className="flex items-center gap-2">
              {isScanning && (
                <span className="text-xs text-gray-400 animate-pulse mr-2">
                  {scannedCount} {t.trackCount}...
                </span>
              )}

              {/* Multi-select toggle */}
              <button
                onClick={() => {
                  setIsSelectMode(!isSelectMode);
                  if (isSelectMode) setSelectedPaths(new Set());
                }}
                className={`px-3 py-1.5 rounded-full text-xs font-semibold flex items-center gap-1.5 transition ${isSelectMode ? accentButton : 'bg-black/5 dark:bg-white/5 hover:bg-black/10 dark:hover:bg-white/10'}`}
              >
                <i className={`fa-solid ${isSelectMode ? 'fa-check-double' : 'fa-list-check'} text-xs`} />
                <span>{isSelectMode ? t.finishSelect : t.batchSelect}</span>
              </button>

              {/* Sort Selector */}
              <M3Dropdown
                value={sortKey}
                onChange={v => setSortKey(v as SortKey)}
                options={sortOptions}
                className="shrink-0 whitespace-nowrap min-w-[130px]"
                buttonClassName="min-w-[130px] whitespace-nowrap"
              />

              {/* Rescan Library Button (Task 2) */}
              <button
                onClick={rescanLibraryAction}
                title={t.rescanLibrary}
                disabled={isScanning}
                className={`px-3 py-1.5 rounded-full bg-black/5 dark:bg-white/5 hover:bg-black/10 dark:hover:bg-white/10 text-xs font-semibold flex items-center gap-1.5 transition ${isScanning ? 'opacity-50 cursor-not-allowed' : ''}`}
              >
                <i className={`fa-solid fa-arrows-rotate text-xs ${isScanning ? 'animate-spin text-md-primary' : ''}`} />
                <span className="hidden sm:inline">{t.rescanLibrary}</span>
              </button>

              {/* View Mode Toggle (Grid/List) */}
              <button
                onClick={() => setViewMode(viewMode === 'grid' ? 'list' : 'grid')}
                className="w-9 h-9 rounded-full bg-black/5 dark:bg-white/5 flex items-center justify-center hover:bg-black/10 transition"
              >
                <i className={`fa-solid ${viewMode === 'grid' ? 'fa-list' : 'fa-th-large'} text-sm`} />
              </button>
            </div>

          </div>

          {/* Filter Chips */}
          {!selectedGroup && (
            <div className="flex items-center space-x-3 overflow-x-auto pb-1">
              {(['titles', 'artists', 'albums', 'folders'] as FilterChip[]).map(chip => (
                <button
                  key={chip}
                  onClick={() => {
                    setFilterChip(chip);
                    setSelectedGroup(null);
                    if (chip === 'titles') setSortKey('title_asc');
                    else if (chip === 'artists') setSortKey('artist_asc');
                    else if (chip === 'albums') setSortKey('album_asc');
                    else if (chip === 'folders') setSortKey('folder_asc');
                  }}
                  className={`px-4 py-1.5 rounded-xl text-xs font-medium transition flex items-center space-x-1.5 shrink-0 ${filterChip === chip ? `${primaryBg} ${primaryText}` : `bg-black/5 dark:bg-white/5 opacity-70 hover:opacity-100`}`}
                >
                  {filterChip === chip && <i className="fa-solid fa-check text-[10px]" />}
                  <span>{t[chip]}</span>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 overflow-auto px-8 pb-24">
        <div className="max-w-7xl mx-auto">
          {libraryTracks.length === 0 ? (
            <div className={`${card} rounded-3xl p-16 flex flex-col items-center justify-center gap-4 text-center mt-4`}>
              <i className={`fa-solid fa-music text-5xl ${primaryText} opacity-40`} />
              <p className="text-sm text-gray-500 dark:text-gray-400">{t.emptyLibrary}</p>
              <div className="flex items-center gap-3 mt-2">
                <button
                  onClick={scanDirectoryAction}
                  className={`px-4 py-2 rounded-full ${accentButton} text-xs font-semibold flex items-center gap-2 shadow hover:scale-105 transition`}
                >
                  <i className="fa-solid fa-folder-open" />
                  <span>{t.openFolder}</span>
                </button>
                <button
                  onClick={importFilesAction}
                  className="px-4 py-2 rounded-full bg-black/5 dark:bg-white/5 hover:bg-black/10 dark:hover:bg-white/10 text-xs font-semibold flex items-center gap-2 transition"
                >
                  <i className="fa-solid fa-file-import" />
                  <span>{t.importFiles}</span>
                </button>
              </div>
            </div>
          ) : selectedGroup?.type === 'artist' ? (
            /* Artist Details: Albums First, Then Tracks */
            <div className="space-y-8 py-4 animate-fade-in">
              {/* 1. Artist's Albums Section */}
              {artistDetailAlbums.length > 0 && (
                <div className="space-y-3">
                  <div className="flex items-center justify-between text-sm font-bold">
                    <span>{t.featuredAlbums} ({artistDetailAlbums.length})</span>
                  </div>
                  {viewMode === 'grid' ? (
                    <M3MediaGrid>
                      {artistDetailAlbums.map(alb => (
                        <M3MediaCard
                          key={alb.name}
                          coverUrl={alb.coverUrl}
                          placeholderType="album"
                          title={alb.name}
                          subTitle={alb.artist}
                          bottomBadge={formatCount(alb.count, 'track', lang)}
                          onClick={() => setSelectedGroup({ type: 'album', name: alb.name, subTitle: `${alb.artist} • ${formatCount(alb.count, 'track', lang)}`, coverUrl: alb.coverUrl })}
                        />
                      ))}
                    </M3MediaGrid>
                  ) : (
                    <div className="space-y-2">
                      {artistDetailAlbums.map(alb => (
                        <M3ListItem
                          key={alb.name}
                          coverUrl={alb.coverUrl}
                          placeholderType="album"
                          title={alb.name}
                          subTitle={`${alb.artist} • ${formatCount(alb.count, 'track', lang)}`}
                          onClick={() => setSelectedGroup({ type: 'album', name: alb.name, subTitle: `${alb.artist} • ${formatCount(alb.count, 'track', lang)}`, coverUrl: alb.coverUrl })}
                          onPlay={alb.tracks.length > 0 ? () => playTrack(alb.tracks[0], alb.tracks) : undefined}
                          showChevron
                        />
                      ))}
                    </div>
                  )}
                </div>
              )}

              {/* 2. Artist's All Tracks Section */}
              <div className="space-y-3">
                <div className="flex items-center justify-between text-sm font-bold">
                  <span>{t.allTracks} ({sortedTracks.length})</span>
                </div>
                <div className="space-y-2">
                  {sortedTracks.map((tr, idx) => {
                    const isFav = isFavorite(tr.path);
                    const isSelected = selectedPaths.has(tr.path);
                    return (
                      <M3ListItem
                        key={tr.path}
                        coverUrl={tr.coverUrl}
                        placeholderType="music"
                        indexNumber={isSelectMode ? undefined : idx + 1}
                        title={tr.title || tr.path.split(/[/\\]/).pop() || ''}
                        subTitle={`${tr.artist || '—'}${tr.album ? ` • ${tr.album}` : ''}`}
                        badge={tr.format}
                        isSelected={isSelected}
                        isSelectMode={isSelectMode}
                        onSelectToggle={e => toggleSelectTrack(tr.path, e)}
                        isFavorited={isFav}
                        onFavorite={() => toggleFavorite(tr.path)}
                        onMenu={() => { setMenuTrack(tr); setIsMenuOpen(true); }}
                        onClick={() => {
                          if (isSelectMode) toggleSelectTrack(tr.path);
                          else playTrack(tr, sortedTracks);
                        }}
                      />
                    );
                  })}
                </div>
              </div>
            </div>
          ) : isBrowsingAggregate ? (
            /* Browsing Aggregate Artists / Albums / Folders */
            <div className="space-y-6 py-4">
              {/* Folders Management Header Toolbar */}
              {filterChip === 'folders' && (
                <div className="flex items-center justify-between pb-2 border-b border-black/5 dark:border-white/5">
                  <div className="text-xs font-bold text-gray-400 flex items-center gap-2">
                    <i className="fa-solid fa-folder-tree" />
                    <span>{t.scannedFoldersTitle}</span>
                    <span className="px-2 py-0.5 rounded-full bg-black/5 dark:bg-white/5 text-[11px]">
                      {foldersList.length}
                    </span>
                  </div>
                  <button
                    onClick={addScanFolderAction}
                    className="px-3 py-1.5 rounded-full bg-md-primary text-md-on-primary text-xs font-bold flex items-center gap-1.5 hover:scale-105 transition shadow-sm"
                  >
                    <i className="fa-solid fa-folder-plus text-xs" />
                    <span>{t.addFolder}</span>
                  </button>
                </div>
              )}

              {/* Artists View */}
              {filterChip === 'artists' && (
                viewMode === 'grid' ? (
                  <M3MediaGrid>
                    {artistsList.map(art => (
                      <M3MediaCard
                        key={art.name}
                        type="circle"
                        coverUrl={art.coverUrl}
                        placeholderType="artist"
                        title={art.name}
                        subTitle={formatCount(art.count, 'track', lang)}
                        onClick={() => setSelectedGroup({ type: 'artist', name: art.name, subTitle: formatCount(art.count, 'track', lang), coverUrl: art.coverUrl })}
                      />
                    ))}
                  </M3MediaGrid>
                ) : (
                  <div className="space-y-2">
                    {artistsList.map(art => (
                      <M3ListItem
                        key={art.name}
                        coverUrl={art.coverUrl}
                        coverShape="circle"
                        placeholderType="artist"
                        title={art.name}
                        subTitle={formatCount(art.count, 'track', lang)}
                        onClick={() => setSelectedGroup({ type: 'artist', name: art.name, subTitle: formatCount(art.count, 'track', lang), coverUrl: art.coverUrl })}
                        showChevron
                      />
                    ))}
                  </div>
                )
              )}

              {/* Albums View */}
              {filterChip === 'albums' && (
                viewMode === 'grid' ? (
                  <M3MediaGrid>
                    {albumsList.map(alb => (
                      <M3MediaCard
                        key={alb.name}
                        coverUrl={alb.coverUrl}
                        placeholderType="album"
                        title={alb.name}
                        subTitle={alb.artist}
                        bottomBadge={formatCount(alb.count, 'track', lang)}
                        onClick={() => setSelectedGroup({ type: 'album', name: alb.name, subTitle: `${alb.artist} • ${formatCount(alb.count, 'track', lang)}`, coverUrl: alb.coverUrl })}
                      />
                    ))}
                  </M3MediaGrid>
                ) : (
                  <div className="space-y-2">
                    {albumsList.map(alb => (
                      <M3ListItem
                        key={alb.name}
                        coverUrl={alb.coverUrl}
                        placeholderType="album"
                        title={alb.name}
                        subTitle={`${alb.artist} • ${formatCount(alb.count, 'track', lang)}`}
                        onClick={() => setSelectedGroup({ type: 'album', name: alb.name, subTitle: `${alb.artist} • ${formatCount(alb.count, 'track', lang)}`, coverUrl: alb.coverUrl })}
                        onPlay={alb.tracks.length > 0 ? () => playTrack(alb.tracks[0], alb.tracks) : undefined}
                        showChevron
                      />
                    ))}
                  </div>
                )
              )}

              {/* Folders View */}
              {filterChip === 'folders' && (
                viewMode === 'grid' ? (
                  <M3MediaGrid>
                    {foldersList.map(fol => (
                      <M3MediaCard
                        key={fol.folderPath}
                        icon="fa-solid fa-folder-open"
                        title={fol.folderName}
                        subTitle={formatCount(fol.count, 'track', lang)}
                        onClick={() => setSelectedGroup({ type: 'folder', name: fol.folderPath, subTitle: `${fol.folderPath} (${formatCount(fol.count, 'track', lang)})` })}
                        customActions={
                          <button
                            onClick={e => {
                              e.stopPropagation();
                              if (window.confirm(t.removeFolderConfirm)) {
                                removeScanFolder(fol.folderPath);
                              }
                            }}
                            className="absolute bottom-2 right-2 w-7 h-7 rounded-full bg-red-500/10 hover:bg-red-500/20 text-red-400 flex items-center justify-center transition opacity-0 group-hover:opacity-100 z-10"
                            title={t.removeFolder}
                          >
                            <i className="fa-solid fa-trash-can text-xs" />
                          </button>
                        }
                      />
                    ))}
                  </M3MediaGrid>
                ) : (
                  <div className="space-y-2">
                    {foldersList.map(fol => (
                      <M3ListItem
                        key={fol.folderPath}
                        icon="fa-solid fa-folder-open"
                        title={fol.folderName}
                        subTitle={`${fol.folderPath} • ${formatCount(fol.count, 'track', lang)}`}
                        onClick={() => setSelectedGroup({ type: 'folder', name: fol.folderPath, subTitle: `${fol.folderPath} (${formatCount(fol.count, 'track', lang)})` })}
                        onDelete={() => {
                          if (window.confirm(t.removeFolderConfirm)) {
                            removeScanFolder(fol.folderPath);
                          }
                        }}
                        showChevron
                      />
                    ))}
                  </div>
                )
              )}
            </div>
          ) : (
            /* Song List / Grid (Native CSS Grid 1:1 with Albums) */
            viewMode === 'grid' ? (
              <M3MediaGrid>
                {sortedTracks.map(tr => {
                  const isFav = isFavorite(tr.path);
                  const isSelected = selectedPaths.has(tr.path);
                  return (
                    <M3MediaCard
                      key={tr.path}
                      coverUrl={tr.coverUrl}
                      placeholderType="music"
                      title={tr.title || tr.path.split(/[/\\]/).pop() || ''}
                      subTitle={tr.artist || 'Unknown Artist'}
                      badge={tr.format}
                      isSelected={isSelected}
                      isSelectMode={isSelectMode}
                      onSelectToggle={e => toggleSelectTrack(tr.path, e)}
                      isFavorited={isFav}
                      onFavorite={() => toggleFavorite(tr.path)}
                      onMenu={() => { setMenuTrack(tr); setIsMenuOpen(true); }}
                      onClick={() => {
                        if (isSelectMode) toggleSelectTrack(tr.path);
                        else playTrack(tr, sortedTracks);
                      }}
                    />
                  );
                })}
              </M3MediaGrid>
            ) : (
              <div className="space-y-2">
                {sortedTracks.map(tr => {
                  const isFav = isFavorite(tr.path);
                  const isSelected = selectedPaths.has(tr.path);
                  return (
                    <M3ListItem
                      key={tr.path}
                      coverUrl={tr.coverUrl}
                      placeholderType="music"
                      title={tr.title || tr.path.split(/[/\\]/).pop() || ''}
                      subTitle={`${tr.artist || 'Unknown Artist'} • ${tr.album || 'Single'}`}
                      badge={tr.format}
                      isSelected={isSelected}
                      isSelectMode={isSelectMode}
                      onSelectToggle={e => toggleSelectTrack(tr.path, e)}
                      isFavorited={isFav}
                      onFavorite={() => toggleFavorite(tr.path)}
                      onMenu={() => { setMenuTrack(tr); setIsMenuOpen(true); }}
                      onClick={() => {
                        if (isSelectMode) toggleSelectTrack(tr.path);
                        else playTrack(tr, sortedTracks);
                      }}
                    />
                  );
                })}
              </div>
            )
          )}
        </div>
      </div>

      {/* Floating Multi-Select Action Bar */}
      {selectedPaths.size > 0 && (
        <div className="fixed bottom-24 left-1/2 -translate-x-1/2 z-40 bg-md-surface-variant text-md-on-surface-variant px-6 py-3.5 rounded-full shadow-2xl flex items-center gap-4 animate-fade-in backdrop-blur-md">
          <span className="text-xs font-semibold">
            {t.selectedCount} <b className="text-md-primary">{selectedPaths.size}</b> {t.trackCount}
          </span>

          <div className="h-4 w-px bg-white/20" />

          <button
            onClick={handleSelectAll}
            className="text-xs text-gray-300 hover:text-white transition"
          >
            {selectedPaths.size === sortedTracks.length ? t.deselectAll : t.selectAll}
          </button>

          <button
            onClick={handleBatchPlay}
            className="px-3.5 py-1.5 rounded-full bg-md-primary text-md-on-primary text-xs font-bold hover:scale-105 transition flex items-center gap-1.5"
          >
            <i className="fa-solid fa-play text-[10px]" />
            <span>{t.batchPlay}</span>
          </button>

          <button
            onClick={handleBatchAddToQueue}
            className="px-3.5 py-1.5 rounded-full bg-white/10 hover:bg-white/20 text-xs font-semibold transition"
          >
            {t.batchAddToQueue}
          </button>

          <button
            onClick={() => setShowBatchPlaylistModal(true)}
            className="px-3.5 py-1.5 rounded-full bg-white/10 hover:bg-white/20 text-xs font-semibold transition"
          >
            {t.batchAddToPlaylist}
          </button>

          <button
            onClick={handleBatchRemoveFromLibrary}
            className="px-3.5 py-1.5 rounded-full bg-red-500/20 text-red-300 hover:bg-red-500/30 text-xs font-semibold transition"
          >
            {t.batchRemoveFromLibrary}
          </button>

          <button
            onClick={() => setIsSelectMode(false)}
            className="w-7 h-7 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-gray-300 hover:text-white transition"
          >
            <i className="fa-solid fa-xmark text-xs" />
          </button>
        </div>
      )}

      {/* Batch Add to Playlist Modal */}
      {showBatchPlaylistModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className={`${card} rounded-3xl p-6 max-w-sm w-full space-y-4 shadow-2xl animate-fade-in`}>
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-base">{t.batchAddToPlaylist}</h3>
              <button
                onClick={() => setShowBatchPlaylistModal(false)}
                className="w-8 h-8 rounded-full hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-center transition"
              >
                <i className="fa-solid fa-xmark" />
              </button>
            </div>

            <div className="space-y-2 max-h-48 overflow-y-auto">
              {playlists.map(pl => (
                <button
                  key={pl.id}
                  onClick={() => handleBatchAddToPlaylist(pl.id)}
                  className="w-full flex items-center justify-between p-3 rounded-2xl bg-black/5 dark:bg-white/5 hover:bg-black/10 dark:hover:bg-white/10 transition text-left text-xs font-semibold"
                >
                  <span className="truncate">{pl.name}</span>
                  <span className="text-gray-400 text-[11px]">{pl.trackPaths.length}</span>
                </button>
              ))}
            </div>

            <div className="pt-2 border-t border-black/10 dark:border-white/10 space-y-2">
              <div className="text-xs font-semibold">{t.createAndAdd}</div>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder={t.newPlaylistPlaceholder}
                  value={newPlaylistName}
                  onChange={e => setNewPlaylistName(e.target.value)}
                  className="flex-1 bg-black/5 dark:bg-white/5 rounded-xl px-3 py-2 text-xs focus:outline-none"
                />
                <button
                  onClick={handleCreateAndAddBatch}
                  className="px-4 py-2 rounded-xl bg-md-primary text-md-on-primary text-xs font-bold"
                >
                  {t.create}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Track Action Menu Modal */}
      <TrackActionMenu
        track={menuTrack}
        isOpen={isMenuOpen}
        onClose={() => { setIsMenuOpen(false); setMenuTrack(null); }}
      />
    </div>
  );
};