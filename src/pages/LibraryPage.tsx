import React, { useState, useRef, useEffect, useMemo, useCallback } from 'react';
import { useVirtualizer } from '@tanstack/react-virtual';
import { usePlayer, splitArtists } from '../context/PlayerContext';
import { I18N, formatCount } from '../i18n';
import { M3CoverImage } from '../components/M3CoverImage';
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
    isDarkMode, lang, libraryTracks, playTrack,
    isScanning, scannedCount, scanDirectoryAction, importFilesAction,
    scannedFolders, addScanFolderAction, removeScanFolder, rescanLibraryAction,
    isFavorite, toggleFavorite, removeTracksFromLibrary,
    playlists, createPlaylist, addTrackToPlaylist, addToQueue,
    artistSeparators,
  } = usePlayer();

  const t = I18N[lang];
  const [filterChip, setFilterChip] = useState<FilterChip>('titles');
  const [viewMode, setViewMode] = useState<ViewMode>('grid');
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

  const card = isDarkMode ? 'bg-[#28272F]' : 'bg-[#E2DBE8]';
  const primaryText = isDarkMode ? 'text-[#39C5BB]' : 'text-[#006A6B]';
  const primaryBg = isDarkMode ? 'bg-[#39C5BB]/20' : 'bg-[#39C5BB]/15';
  const accentButton = isDarkMode ? 'bg-[#39C5BB] text-[#003738]' : 'bg-[#006A6B] text-white';

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

  // Virtualization columns calculation
  const parentRef = useRef<HTMLDivElement>(null);
  const [cols, setCols] = useState(() => {
    if (typeof window === 'undefined') return 5;
    const w = window.innerWidth;
    if (w >= 1600) return 8;
    if (w >= 1350) return 7;
    if (w >= 1100) return 6;
    if (w >= 850) return 5;
    return 4;
  });

  useEffect(() => {
    const handleResize = () => {
      const w = window.innerWidth;
      if (w >= 1600) setCols(8);
      else if (w >= 1350) setCols(7);
      else if (w >= 1100) setCols(6);
      else if (w >= 850) setCols(5);
      else setCols(4);
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  const isBrowsingAggregate = !selectedGroup && filterChip !== 'titles';
  const aggregateItemCount = filterChip === 'artists'
    ? artistsList.length
    : filterChip === 'albums'
    ? albumsList.length
    : foldersList.length;

  const currentDisplayCount = isBrowsingAggregate ? aggregateItemCount : sortedTracks.length;
  const GRID_ROW_HEIGHT = 220;
  const LIST_ROW_HEIGHT = 64;
  const rowCount = viewMode === 'grid' ? Math.ceil(currentDisplayCount / cols) : currentDisplayCount;

  const rowVirtualizer = useVirtualizer({
    count: selectedGroup?.type === 'artist' ? 0 : rowCount,
    getScrollElement: () => parentRef.current,
    estimateSize: () => viewMode === 'grid' ? GRID_ROW_HEIGHT : LIST_ROW_HEIGHT,
    overscan: 3,
  });

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
      <div className={`px-8 pt-8 pb-4 shrink-0 ${isDarkMode ? 'bg-[#131317]' : 'bg-[#F6F2F8]'}`}>
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
                <span className="text-xs text-gray-400 animate-pulse mr-2 font-mono">
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
              />

              {/* Rescan Library Button (Task 2) */}
              <button
                onClick={rescanLibraryAction}
                title={t.rescanLibrary}
                disabled={isScanning}
                className={`px-3 py-1.5 rounded-full bg-black/5 dark:bg-white/5 hover:bg-black/10 dark:hover:bg-white/10 text-xs font-semibold flex items-center gap-1.5 transition ${isScanning ? 'opacity-50 cursor-not-allowed' : ''}`}
              >
                <i className={`fa-solid fa-arrows-rotate text-xs ${isScanning ? 'animate-spin text-[#39C5BB]' : ''}`} />
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
      <div ref={parentRef} className="flex-1 overflow-auto px-8 pb-24">
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
            /* Artist Details Refactor: Albums First, Then Tracks (Task 5) */
            <div className="space-y-8 py-4 animate-fade-in">
              {/* 1. Artist's Albums Section */}
              {artistDetailAlbums.length > 0 && (
                <div className="space-y-3">
                  <div className="flex items-center justify-between text-sm font-bold">
                    <span>{t.featuredAlbums} ({artistDetailAlbums.length})</span>
                  </div>
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-5">
                    {artistDetailAlbums.map(alb => (
                      <div
                        key={alb.name}
                        onClick={() => setSelectedGroup({ type: 'album', name: alb.name, subTitle: `${alb.artist} • ${formatCount(alb.count, 'track', lang)}`, coverUrl: alb.coverUrl })}
                        className={`${card} p-3.5 rounded-3xl cursor-pointer group flex flex-col justify-between hover:scale-[1.02] transition shadow-sm`}
                      >
                        <div className="aspect-square rounded-2xl overflow-hidden mb-2.5 relative">
                          <M3CoverImage
                            src={alb.coverUrl}
                            alt={alb.name}
                            placeholderType="album"
                            imageClassName="group-hover:scale-105 transition duration-300"
                          />
                          <span className="absolute bottom-2 left-2 text-white text-[10px] font-semibold bg-black/50 backdrop-blur-xs px-2 py-0.5 rounded-md">
                            {formatCount(alb.count, 'track', lang)}
                          </span>
                        </div>
                        <div>
                          <div className={`font-bold text-xs truncate transition ${isDarkMode ? 'group-hover:text-[#39C5BB]' : 'group-hover:text-[#006A6B]'}`}>{alb.name}</div>
                          <div className="text-[11px] text-gray-500 truncate mt-0.5">{alb.artist}</div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* 2. Artist's All Tracks Section */}
              <div className="space-y-3">
                <div className="flex items-center justify-between text-sm font-bold">
                  <span>{t.allTracks} ({sortedTracks.length})</span>
                </div>
                <div className="space-y-1">
                  {sortedTracks.map((tr, idx) => {
                    const isFav = isFavorite(tr.path);
                    const isSelected = selectedPaths.has(tr.path);
                    return (
                      <div
                        key={tr.path}
                        onClick={() => {
                          if (isSelectMode) toggleSelectTrack(tr.path);
                          else playTrack(tr, sortedTracks);
                        }}
                        className={`${card} rounded-2xl flex items-center justify-between gap-4 px-4 py-3 cursor-pointer group hover:bg-[#36343B] dark:hover:bg-[#36343B] transition my-0.5 ${isSelected ? 'ring-2 ring-[#39C5BB]' : ''}`}
                      >
                        <div className="flex items-center space-x-3.5 min-w-0 flex-1">
                          {isSelectMode ? (
                            <input
                              type="checkbox"
                              checked={isSelected}
                              onChange={() => {}}
                              onClick={e => toggleSelectTrack(tr.path, e)}
                              className="w-4 h-4 accent-[#39C5BB] rounded cursor-pointer mr-1"
                            />
                          ) : (
                            <span className="w-5 text-center text-xs font-mono text-gray-400">{idx + 1}</span>
                          )}
                          <div className="w-11 h-11 rounded-xl overflow-hidden shrink-0">
                            <M3CoverImage
                              src={tr.coverUrl}
                              alt={tr.title}
                              placeholderType="music"
                              className="w-11 h-11 rounded-xl"
                              iconClassName="text-base"
                            />
                          </div>

                          <div className="min-w-0 flex-1">
                            <div className="font-semibold text-sm truncate">{tr.title || tr.path.split(/[/\\]/).pop()}</div>
                            <div className="text-xs text-gray-500 dark:text-gray-400 truncate">{tr.artist || '—'} {tr.album ? `• ${tr.album}` : ''}</div>
                          </div>
                        </div>

                        {!isSelectMode && (
                          <div className="flex items-center space-x-2 shrink-0">
                            {tr.format && (
                              <span className="text-[10px] font-mono text-amber-400 hidden sm:inline mr-2">{tr.format.split(' ')[0]}</span>
                            )}
                            <button
                              onClick={e => { e.stopPropagation(); toggleFavorite(tr.path); }}
                              className={`w-8 h-8 rounded-full flex items-center justify-center transition ${isFav ? 'text-red-500' : 'text-gray-400 opacity-0 group-hover:opacity-100 hover:text-red-400'}`}
                            >
                              <i className="fa-solid fa-heart text-xs" />
                            </button>
                            <button
                              onClick={e => { e.stopPropagation(); setMenuTrack(tr); setIsMenuOpen(true); }}
                              className="w-8 h-8 rounded-full hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-center opacity-0 group-hover:opacity-100 transition"
                            >
                              <i className="fa-solid fa-ellipsis-vertical text-xs opacity-70" />
                            </button>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          ) : isBrowsingAggregate ? (
            /* Browsing Aggregate Artists / Albums / Folders */
            <div className="space-y-6 py-4">
              {/* Folders Management Header Toolbar (Task 2) */}
              {filterChip === 'folders' && (
                <div className="flex items-center justify-between pb-2 border-b border-black/5 dark:border-white/5">
                  <div className="text-xs font-bold text-gray-400 flex items-center gap-2">
                    <i className="fa-solid fa-folder-tree" />
                    <span>{t.scannedFoldersTitle}</span>
                    <span className="px-2 py-0.5 rounded-full bg-black/5 dark:bg-white/5 font-mono text-[11px]">
                      {foldersList.length}
                    </span>
                  </div>
                  <button
                    onClick={addScanFolderAction}
                    className="px-3 py-1.5 rounded-full bg-[#006A6B] dark:bg-[#39C5BB] text-white dark:text-[#003738] text-xs font-bold flex items-center gap-1.5 hover:scale-105 transition shadow-sm"
                  >
                    <i className="fa-solid fa-folder-plus text-xs" />
                    <span>{t.addFolder}</span>
                  </button>
                </div>
              )}

              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-5">
                {filterChip === 'artists' &&
                  artistsList.map(art => (
                    <div
                      key={art.name}
                      onClick={() => setSelectedGroup({ type: 'artist', name: art.name, subTitle: formatCount(art.count, 'track', lang), coverUrl: art.coverUrl })}
                      className={`${card} p-4 rounded-3xl cursor-pointer group flex flex-col items-center text-center hover:scale-[1.02] transition shadow-sm`}
                    >
                      <div className="w-24 h-24 rounded-full overflow-hidden mb-3 relative">
                        <M3CoverImage
                          src={art.coverUrl}
                          alt={art.name}
                          placeholderType="artist"
                          className="w-24 h-24 rounded-full"
                          iconClassName="text-3xl"
                          imageClassName="group-hover:scale-105 transition duration-300"
                        />
                      </div>
                      <div className={`font-bold text-sm truncate w-full transition ${isDarkMode ? 'group-hover:text-[#39C5BB]' : 'group-hover:text-[#006A6B]'}`}>{art.name}</div>
                      <div className="text-xs text-gray-500 mt-1">{formatCount(art.count, 'track', lang)}</div>
                    </div>
                  ))}

                {filterChip === 'albums' &&
                  albumsList.map(alb => (
                    <div
                      key={alb.name}
                      onClick={() => setSelectedGroup({ type: 'album', name: alb.name, subTitle: `${alb.artist} • ${formatCount(alb.count, 'track', lang)}`, coverUrl: alb.coverUrl })}
                      className={`${card} p-3.5 rounded-3xl cursor-pointer group flex flex-col justify-between hover:scale-[1.02] transition shadow-sm`}
                    >
                      <div className="aspect-square rounded-2xl overflow-hidden mb-2.5 relative">
                        <M3CoverImage
                          src={alb.coverUrl}
                          alt={alb.name}
                          placeholderType="album"
                          imageClassName="group-hover:scale-105 transition duration-300"
                        />
                        <span className="absolute bottom-2 left-2 text-white text-[10px] font-semibold bg-black/50 backdrop-blur-xs px-2 py-0.5 rounded-md">
                          {formatCount(alb.count, 'track', lang)}
                        </span>
                      </div>
                      <div>
                        <div className={`font-bold text-xs truncate transition ${isDarkMode ? 'group-hover:text-[#39C5BB]' : 'group-hover:text-[#006A6B]'}`}>{alb.name}</div>
                        <div className="text-[11px] text-gray-500 truncate mt-0.5">{alb.artist}</div>
                      </div>
                    </div>
                  ))}


                {filterChip === 'folders' &&
                  foldersList.map(fol => (
                    <div
                      key={fol.folderPath}
                      onClick={() => setSelectedGroup({ type: 'folder', name: fol.folderPath, subTitle: `${fol.folderPath} (${formatCount(fol.count, 'track', lang)})` })}
                      className={`${card} p-4 rounded-3xl cursor-pointer group flex flex-col justify-between hover:scale-[1.02] transition shadow-sm relative`}
                    >
                      <div className={`h-20 rounded-2xl mb-2.5 ${isDarkMode ? 'bg-[#39C5BB]/20' : 'bg-[#39C5BB]/15'} flex items-center justify-center text-3xl`}>
                        <i className={`fa-solid fa-folder-open ${primaryText}`} />
                      </div>
                      <div className="pr-6">
                        <div className={`font-bold text-xs truncate transition ${isDarkMode ? 'group-hover:text-[#39C5BB]' : 'group-hover:text-[#006A6B]'}`}>{fol.folderName}</div>
                        <div className="text-[10px] text-gray-500 truncate mt-0.5">{formatCount(fol.count, 'track', lang)}</div>
                      </div>

                      {/* Remove Folder Button (Task 2) */}
                      <button
                        onClick={e => {
                          e.stopPropagation();
                          if (window.confirm(t.removeFolderConfirm)) {
                            removeScanFolder(fol.folderPath);
                          }
                        }}
                        className="absolute bottom-3 right-3 w-7 h-7 rounded-full bg-red-500/10 hover:bg-red-500/20 text-red-400 flex items-center justify-center transition opacity-0 group-hover:opacity-100"
                        title={t.removeFolder}
                      >
                        <i className="fa-solid fa-trash-can text-xs" />
                      </button>
                    </div>
                  ))}
              </div>
            </div>
          ) : (
            /* Virtualized Song List / Grid */
            <div style={{ height: rowVirtualizer.getTotalSize(), position: 'relative' }}>
              {rowVirtualizer.getVirtualItems().map(vRow => {
                if (viewMode === 'grid') {
                  const rowTracks = sortedTracks.slice(vRow.index * cols, vRow.index * cols + cols);
                  return (
                    <div
                      key={vRow.key}
                      style={{ position: 'absolute', top: vRow.start, left: 0, right: 0 }}
                    >
                      <div
                        className="py-2"
                        style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: '1.25rem' }}
                      >
                        {rowTracks.map(tr => {
                          const isFav = isFavorite(tr.path);
                          const isSelected = selectedPaths.has(tr.path);
                          return (
                            <div
                              key={tr.path}
                              onClick={() => {
                                if (isSelectMode) toggleSelectTrack(tr.path);
                                else playTrack(tr, sortedTracks);
                              }}
                              className={`${card} p-3.5 rounded-3xl cursor-pointer group hover:-translate-y-0.5 transition-all duration-200 relative ${isSelected ? 'ring-2 ring-[#39C5BB]' : ''}`}
                            >
                              <div className="relative aspect-square rounded-2xl overflow-hidden mb-3">
                                <M3CoverImage
                                  src={tr.coverUrl}
                                  alt={tr.title}
                                  placeholderType="music"
                                  imageClassName="group-hover:scale-105 transition duration-300"
                                />

                                {/* Checkbox for select mode */}
                                {isSelectMode && (
                                  <div
                                    onClick={e => toggleSelectTrack(tr.path, e)}
                                    className="absolute top-2 left-2 z-10 w-6 h-6 rounded-full bg-black/60 flex items-center justify-center"
                                  >
                                    <input
                                      type="checkbox"
                                      checked={isSelected}
                                      onChange={() => {}}
                                      className="w-4 h-4 accent-[#39C5BB] rounded cursor-pointer"
                                    />
                                  </div>
                                )}

                                {tr.format && !isSelectMode && (
                                  <span className="absolute top-2 right-2 bg-black/60 backdrop-blur-md px-2 py-0.5 rounded-full text-[9px] font-mono text-amber-300 border border-white/10">
                                    {tr.format.split(' ')[0]}
                                  </span>
                                )}

                                {!isSelectMode && (
                                  <>
                                    <button
                                      onClick={e => { e.stopPropagation(); setMenuTrack(tr); setIsMenuOpen(true); }}
                                      className="absolute bottom-2 right-2 w-7 h-7 rounded-full bg-black/50 text-white flex items-center justify-center opacity-0 group-hover:opacity-100 hover:bg-black/80 transition"
                                      title={t.moreActions}
                                    >
                                      <i className="fa-solid fa-ellipsis-vertical text-[11px]" />
                                    </button>
                                    <button
                                      onClick={e => { e.stopPropagation(); toggleFavorite(tr.path); }}
                                      className={`absolute bottom-2 left-2 w-7 h-7 rounded-full bg-black/50 flex items-center justify-center transition ${isFav ? 'text-red-500 opacity-100' : 'text-white opacity-0 group-hover:opacity-100 hover:text-red-400'}`}
                                      title={isFav ? t.favorited : t.favorite}
                                    >
                                      <i className="fa-solid fa-heart text-[11px]" />
                                    </button>
                                  </>
                                )}
                              </div>
                              <div className="font-semibold text-sm truncate">{tr.title || tr.path.split(/[/\\]/).pop()}</div>
                              <div className="text-xs text-gray-500 dark:text-gray-400 mt-0.5 truncate">{tr.artist || '—'}</div>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  );
                } else {
                  const tr = sortedTracks[vRow.index];
                  const isFav = isFavorite(tr.path);
                  const isSelected = selectedPaths.has(tr.path);
                  return (
                    <div
                      key={vRow.key}
                      style={{ position: 'absolute', top: vRow.start, left: 0, right: 0 }}
                    >
                      <div
                        onClick={() => {
                          if (isSelectMode) toggleSelectTrack(tr.path);
                          else playTrack(tr, sortedTracks);
                        }}
                        className={`${card} rounded-2xl flex items-center justify-between gap-4 px-4 py-3 cursor-pointer group hover:bg-[#36343B] dark:hover:bg-[#36343B] transition my-0.5 ${isSelected ? 'ring-2 ring-[#39C5BB]' : ''}`}
                      >
                        <div className="flex items-center space-x-3.5 min-w-0 flex-1">
                          {isSelectMode && (
                            <input
                              type="checkbox"
                              checked={isSelected}
                              onChange={() => {}}
                              onClick={e => toggleSelectTrack(tr.path, e)}
                              className="w-4 h-4 accent-[#39C5BB] rounded cursor-pointer mr-1"
                            />
                          )}
                          <div className="w-11 h-11 rounded-xl overflow-hidden shrink-0">
                            <M3CoverImage
                              src={tr.coverUrl}
                              alt={tr.title}
                              placeholderType="music"
                              className="w-11 h-11 rounded-xl"
                              iconClassName="text-base"
                            />
                          </div>

                          <div className="min-w-0 flex-1">
                            <div className="font-semibold text-sm truncate">{tr.title || tr.path.split(/[/\\]/).pop()}</div>
                            <div className="text-xs text-gray-500 dark:text-gray-400 truncate">{tr.artist || '—'} {tr.album ? `• ${tr.album}` : ''}</div>
                          </div>
                        </div>

                        {!isSelectMode && (
                          <div className="flex items-center space-x-2 shrink-0">
                            {tr.format && (
                              <span className="text-[10px] font-mono text-amber-400 hidden sm:inline mr-2">{tr.format.split(' ')[0]}</span>
                            )}
                            <button
                              onClick={e => { e.stopPropagation(); toggleFavorite(tr.path); }}
                              className={`w-8 h-8 rounded-full flex items-center justify-center transition ${isFav ? 'text-red-500' : 'text-gray-400 opacity-0 group-hover:opacity-100 hover:text-red-400'}`}
                              title={isFav ? t.favorited : t.favorite}
                            >
                              <i className="fa-solid fa-heart text-xs" />
                            </button>
                            <button
                              onClick={e => { e.stopPropagation(); setMenuTrack(tr); setIsMenuOpen(true); }}
                              className="w-8 h-8 rounded-full hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-center opacity-0 group-hover:opacity-100 transition"
                              title={t.moreActions}
                            >
                              <i className="fa-solid fa-ellipsis-vertical text-xs opacity-70" />
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                  );
                }
              })}
            </div>
          )}
        </div>
      </div>

      {/* Floating Multi-Select Action Bar */}
      {selectedPaths.size > 0 && (
        <div className="fixed bottom-24 left-1/2 -translate-x-1/2 z-40 bg-[#1E1D24] text-white border border-white/10 px-6 py-3.5 rounded-full shadow-2xl flex items-center gap-4 animate-fade-in backdrop-blur-md">
          <span className="text-xs font-semibold">
            {t.selectedCount} <b className="text-[#39C5BB]">{selectedPaths.size}</b> {t.trackCount}
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
            className="px-3.5 py-1.5 rounded-full bg-[#39C5BB] text-[#003738] text-xs font-bold hover:scale-105 transition flex items-center gap-1.5"
          >
            <i className="fa-solid fa-play text-[10px]" />
            <span>{t.batchPlay}</span>
          </button>

          <button
            onClick={handleBatchAddToQueue}
            className="px-3 py-1.5 rounded-full bg-white/10 hover:bg-white/20 text-xs font-semibold transition"
          >
            {t.batchAddToQueue}
          </button>

          <button
            onClick={() => setShowBatchPlaylistModal(true)}
            className="px-3 py-1.5 rounded-full bg-white/10 hover:bg-white/20 text-xs font-semibold transition"
          >
            {t.batchAddToPlaylist}
          </button>

          <button
            onClick={handleBatchRemoveFromLibrary}
            className="px-3 py-1.5 rounded-full bg-red-500/20 text-red-300 hover:bg-red-500/30 text-xs font-semibold transition"
          >
            {t.batchRemoveFromLibrary}
          </button>

          <button
            onClick={() => setSelectedPaths(new Set())}
            className="w-7 h-7 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center transition"
          >
            <i className="fa-solid fa-xmark text-xs" />
          </button>
        </div>
      )}

      {/* Batch Add to Playlist Modal */}
      {showBatchPlaylistModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-fade-in">
          <div className={`${isDarkMode ? 'bg-[#28272F]' : 'bg-white'} rounded-3xl p-6 max-w-sm w-full space-y-4 shadow-2xl`}>
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-base">{t.batchAddTitle} ({selectedPaths.size})</h3>
              <button onClick={() => setShowBatchPlaylistModal(false)} className="opacity-60 hover:opacity-100">
                <i className="fa-solid fa-xmark text-sm" />
              </button>
            </div>

            <div className="max-h-60 overflow-y-auto space-y-2 py-1">
              {playlists.map(pl => (
                <button
                  key={pl.id}
                  onClick={() => handleBatchAddToPlaylist(pl.id)}
                  className="w-full p-3 rounded-2xl text-left bg-black/5 dark:bg-white/5 hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-between transition"
                >
                  <div className="truncate">
                    <div className="font-semibold text-xs truncate">{pl.name}</div>
                    <div className="text-[10px] text-gray-500">{formatCount(pl.trackPaths.length, 'track', lang)}</div>
                  </div>
                  <i className="fa-solid fa-plus text-xs opacity-60" />
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
                  className="px-4 py-2 rounded-xl bg-[#39C5BB] text-[#003738] text-xs font-bold"
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