import React, { useState } from 'react';
import { usePlayer, ALL_NAV_ITEMS, NavTab } from '../context/PlayerContext';
import { I18N } from '../i18n';

interface NavOrderItem {
  id: NavTab;
  visible: boolean;
}

export const NavigationRail: React.FC = () => {
  const {
    activeTab, setActiveTab,
    isDarkMode,
    lang,
    visibleNavIds, setVisibleNavIds,
    isNowPlayingOpen, setIsNowPlayingOpen,
    isNavCollapsed: isCollapsed,
    setIsNavCollapsed: setIsCollapsed,
  } = usePlayer();

  const t = I18N[lang];
  const [isEditingNav, setIsEditingNav] = useState(false);
  const [tempOrder, setTempOrder] = useState<NavOrderItem[]>([]);

  const handleTabClick = (tab: NavTab) => {
    if (isNowPlayingOpen) {
      setIsNowPlayingOpen(false);
    }
    setActiveTab(tab);
  };


  const surface = 'bg-md-surface-container-low';
  const primaryText = 'text-md-primary';

  const activeClass = 'bg-md-primary-container text-md-on-primary-container font-bold shadow-xs';
  const inactiveClass = 'text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-100 hover:bg-black/5 dark:hover:bg-white/5';

  const openEditNav = () => {
    // Build ordered list: visible ones in current order first, followed by hidden ones
    const currentVisibleSet = new Set(visibleNavIds);
    const visiblePart: NavOrderItem[] = visibleNavIds.map(id => ({ id, visible: true }));
    const hiddenPart: NavOrderItem[] = ALL_NAV_ITEMS
      .filter(item => !currentVisibleSet.has(item.id))
      .map(item => ({ id: item.id, visible: false }));
    setTempOrder([...visiblePart, ...hiddenPart]);
    setIsEditingNav(true);
  };

  const toggleItemVisibility = (id: NavTab) => {
    if (id === 'home') return;
    setTempOrder(prev =>
      prev.map(item => item.id === id ? { ...item, visible: !item.visible } : item)
    );
  };

  const moveItem = (index: number, direction: 'up' | 'down') => {
    const targetIndex = direction === 'up' ? index - 1 : index + 1;
    if (targetIndex < 0 || targetIndex >= tempOrder.length) return;
    setTempOrder(prev => {
      const next = [...prev];
      const temp = next[index];
      next[index] = next[targetIndex];
      next[targetIndex] = temp;
      return next;
    });
  };

  const saveNavCustomization = () => {
    const newVisibleIds = tempOrder.filter(item => item.visible).map(item => item.id);
    // Ensure home is included
    if (!newVisibleIds.includes('home')) {
      newVisibleIds.unshift('home');
    }
    setVisibleNavIds(newVisibleIds);
    if (!newVisibleIds.includes(activeTab) && activeTab !== 'settings') {
      setActiveTab('home');
    }
    setIsEditingNav(false);
  };

  // Map to get nav item metadata
  const navItemMap = new Map(ALL_NAV_ITEMS.map(i => [i.id, i]));

  return (
    <>
      <aside
        className={`${isCollapsed ? 'w-18 w-[4.5rem]' : 'w-56'} ${surface} flex flex-col justify-between py-5 shrink-0 z-20 transition-all duration-300`}
      >
        <div className="flex flex-col gap-4 w-full px-3">
          {/* Brand & collapse toggle */}
          <div className="flex items-center justify-between px-2">
            {!isCollapsed && (
              <span className={`brand-text font-brand font-extrabold text-base tracking-tight truncate pl-1 ${primaryText}`}>
                {t.appName}
              </span>
            )}
            <button
              onClick={() => setIsCollapsed(!isCollapsed)}
              title={isCollapsed ? t.expandRail : t.collapseRail}
              className="w-8 h-8 rounded-full flex items-center justify-center hover:bg-black/10 dark:hover:bg-white/10 transition shrink-0 mx-auto md:mx-0"
            >
              <i className={`fa-solid ${isCollapsed ? 'fa-indent' : 'fa-outdent'} text-sm opacity-80`} />
            </button>
          </div>

          {/* Edit nav button (FAB style) */}
          <button
            onClick={openEditNav}
            title={t.navRailCustom}
            className={`rounded-2xl bg-md-primary-container text-md-on-primary-container flex items-center hover:scale-[1.02] active:scale-95 transition shadow-sm ${isCollapsed ? 'w-11 h-11 justify-center mx-auto' : 'w-full px-4 py-2.5 space-x-3'}`}
          >
            <i className="fa-solid fa-pen text-sm" />
            {!isCollapsed && <span className="text-xs font-semibold">{t.navRailCustom}</span>}
          </button>

          {/* Nav items in ordered sequence */}
          <nav className="flex flex-col gap-1.5 w-full mt-2">
            {visibleNavIds.map(id => {
              const item = navItemMap.get(id);
              if (!item) return null;
              const isActive = activeTab === item.id;
              return (
                <button
                  key={item.id}
                  onClick={() => handleTabClick(item.id)}
                  className={`flex items-center rounded-2xl transition ${isCollapsed ? 'justify-center py-2.5' : 'px-3.5 py-3 space-x-3 text-left'} ${isActive ? activeClass : inactiveClass}`}
                >
                  <div className={`w-9 h-7 rounded-full flex items-center justify-center shrink-0 ${isActive ? 'bg-md-primary text-md-on-primary' : ''}`}>
                    <i className={`fa-solid ${item.icon} text-sm`} />
                  </div>
                  {!isCollapsed && (
                    <span className="text-sm truncate">{t[item.labelKey as keyof typeof t] as string}</span>
                  )}
                </button>
              );
            })}
          </nav>
        </div>

        {/* Bottom: Settings ONLY */}
        <div className="px-3">
          <button
            onClick={() => handleTabClick('settings')}
            title={t.settings}
            className={`w-full flex items-center rounded-2xl transition p-2.5 ${isCollapsed ? 'justify-center' : 'space-x-3 px-3.5 py-3'} ${activeTab === 'settings' ? activeClass : (isDarkMode ? 'text-gray-400 hover:text-gray-100 hover:bg-white/5' : 'text-gray-500 hover:text-gray-900 hover:bg-black/5')}`}
          >
            <i className="fa-solid fa-gear text-base shrink-0" />
            {!isCollapsed && <span className="text-sm truncate">{t.settings}</span>}
          </button>
        </div>

      </aside>

      {/* Nav Customizer Modal with Ordering & Visibility */}
      {isEditingNav && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-fade-in">
          <div className="bg-md-surface-container-high rounded-3xl p-6 max-w-md w-full space-y-4 shadow-2xl">
            <div className="flex items-center justify-between">
              <h3 className={`text-base font-bold flex items-center gap-2 ${primaryText}`}>
                <i className="fa-solid fa-pen-to-square" /> {t.navRailCustom}
              </h3>
              <span className="text-[11px] text-gray-400">{t.navRailOrderHint}</span>
            </div>
            <p className="text-xs text-gray-400">{t.navRailCustomDesc}</p>

            <div className="space-y-2 py-2 max-h-72 overflow-y-auto pr-1">
              {tempOrder.map((entry, index) => {
                const item = navItemMap.get(entry.id);
                if (!item) return null;
                const isHome = entry.id === 'home';
                return (
                  <div
                    key={entry.id}
                    className={`flex items-center justify-between p-3 rounded-2xl transition ${entry.visible ? 'bg-md-primary-container text-md-on-primary-container' : (isDarkMode ? 'bg-white/5 opacity-50' : 'bg-black/5 opacity-50')}`}
                  >
                    <div
                      onClick={() => toggleItemVisibility(entry.id)}
                      className="flex items-center space-x-3 text-xs flex-1 cursor-pointer select-none"
                    >
                      <i className={`fa-solid ${item.icon} text-sm w-5 text-center ${entry.visible ? primaryText : 'opacity-40'}`} />
                      <span className="font-semibold">{t[item.labelKey as keyof typeof t] as string}</span>
                    </div>

                    <div className="flex items-center space-x-2">
                      {/* Order Up & Down Buttons */}
                      <button
                        type="button"
                        disabled={index === 0}
                        onClick={() => moveItem(index, 'up')}
                        title={t.moveUp}
                        className="w-7 h-7 rounded-lg bg-black/10 dark:bg-white/10 hover:bg-black/20 dark:hover:bg-white/20 disabled:opacity-20 flex items-center justify-center transition"
                      >
                        <i className="fa-solid fa-arrow-up text-[10px]" />
                      </button>
                      <button
                        type="button"
                        disabled={index === tempOrder.length - 1}
                        onClick={() => moveItem(index, 'down')}
                        title={t.moveDown}
                        className="w-7 h-7 rounded-lg bg-black/10 dark:bg-white/10 hover:bg-black/20 dark:hover:bg-white/20 disabled:opacity-20 flex items-center justify-center transition"
                      >
                        <i className="fa-solid fa-arrow-down text-[10px]" />
                      </button>


                      <input
                        type="checkbox"
                        checked={entry.visible}
                        disabled={isHome}
                        onChange={() => toggleItemVisibility(entry.id)}
                        className="w-4 h-4 accent-md-primary rounded cursor-pointer ml-1"
                      />
                    </div>
                  </div>
                );
              })}
            </div>

            <div className="flex justify-end space-x-3 pt-3 border-t border-black/5 dark:border-white/5">
              <button
                onClick={() => setIsEditingNav(false)}
                className="px-4 py-2 rounded-full text-xs font-semibold text-gray-400 hover:text-white transition"
              >
                {t.cancel}
              </button>
              <button
                onClick={saveNavCustomization}
                className="px-5 py-2 rounded-full font-bold text-xs hover:opacity-90 transition shadow bg-md-primary text-md-on-primary"
              >
                {t.saveNavCustom}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};


