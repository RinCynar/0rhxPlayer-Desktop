import React from 'react';
import { PlayerProvider, usePlayer } from './context/PlayerContext';
import { NavigationRail } from './components/NavigationRail';
import { BottomPlayerBar } from './components/BottomPlayerBar';
import { NowPlayingDrawer } from './components/NowPlayingDrawer';
import { HomePage } from './pages/HomePage';
import { LibraryPage } from './pages/LibraryPage';
import { PlaylistPage } from './pages/PlaylistPage';
import { SearchPage } from './pages/SearchPage';
import { SettingsPage } from './pages/SettingsPage';
import { QueuePage } from './pages/QueuePage';
import { EQPage } from './pages/EQPage';

const MainLayout: React.FC = () => {
  const { activeTab } = usePlayer();



  const renderContent = () => {
    switch (activeTab) {
      case 'home':     return <HomePage />;
      case 'library':  return <LibraryPage />;
      case 'playlist': return <PlaylistPage />;
      case 'search':   return <SearchPage />;
      case 'settings': return <SettingsPage />;
      case 'queue':    return <QueuePage />;
      case 'eq':       return <EQPage />;
      default:         return <HomePage />;
    }
  };


  return (
    <div className="flex h-screen w-screen overflow-hidden select-none bg-md-surface text-md-on-surface transition-colors duration-300">
      {/* Left Navigation Rail */}
      <NavigationRail />

      {/* Main Workspace Area */}
      <div className="flex-1 flex flex-col min-w-0 h-full relative overflow-hidden">
        {/* Dynamic Page Router */}
        <main className="flex-1 overflow-y-auto relative">
          {renderContent()}
        </main>

        {/* Global Singleton NowPlaying Overlay (Above main content, bottom bar stays persistent) */}
        <div className="absolute inset-x-0 top-0 bottom-20 z-40 overflow-hidden pointer-events-none">
          <NowPlayingDrawer />
        </div>

        {/* Global Bottom Mini Player */}
        <BottomPlayerBar />
      </div>

    </div>
  );
};


export const App: React.FC = () => {
  return (
    <PlayerProvider>
      <MainLayout />
    </PlayerProvider>
  );
};

export default App;
