import React from 'react';
import { M3CoverImage } from './M3CoverImage';

export interface M3ListItemProps {
  coverUrl?: string;
  placeholderType?: 'music' | 'album' | 'artist' | 'folder';
  coverShape?: 'square' | 'circle';
  icon?: string;
  indexNumber?: number | string;
  title: string;
  subTitle?: string;
  badge?: string;
  duration?: string;
  isSelected?: boolean;
  isSelectMode?: boolean;
  onSelectToggle?: (e: React.MouseEvent) => void;
  onClick?: () => void;
  isFavorited?: boolean;
  onFavorite?: (e: React.MouseEvent) => void;
  onMenu?: (e: React.MouseEvent) => void;
  onDelete?: (e: React.MouseEvent) => void;
  onPlay?: (e: React.MouseEvent) => void;
  showChevron?: boolean;
  customActions?: React.ReactNode;
  className?: string;
}

export const M3ListItem: React.FC<M3ListItemProps> = ({
  coverUrl,
  placeholderType = 'music',
  coverShape = 'square',
  icon,
  indexNumber,
  title,
  subTitle,
  badge,
  duration,
  isSelected = false,
  isSelectMode = false,
  onSelectToggle,
  onClick,
  isFavorited,
  onFavorite,
  onMenu,
  onDelete,
  onPlay,
  showChevron = false,
  customActions,
  className = '',
}) => {
  const cardBg = `bg-md-surface-container hover:bg-md-surface-container-high shadow-xs transition-colors duration-150 ${
    isSelected ? 'ring-2 ring-md-primary bg-md-surface-container-highest' : ''
  }`;

  return (
    <div
      onClick={onClick}
      className={`${cardBg} rounded-2xl flex items-center justify-between gap-4 px-4 py-2.5 cursor-pointer group ${className}`}
    >
      <div className="flex items-center space-x-3.5 min-w-0 flex-1">
        {/* Checkbox for select mode */}
        {isSelectMode && onSelectToggle && (
          <input
            type="checkbox"
            checked={isSelected}
            onChange={() => {}}
            onClick={e => {
              e.stopPropagation();
              onSelectToggle(e);
            }}
            className="w-4 h-4 accent-md-primary rounded cursor-pointer mr-1 shrink-0"
          />
        )}

        {/* Index number */}
        {indexNumber !== undefined && (
          <span className="text-xs text-gray-400 w-5 text-center shrink-0">
            {indexNumber}
          </span>
        )}

        {/* Cover / Icon */}
        <div
          className={`w-10 h-10 ${
            coverShape === 'circle' ? 'rounded-full' : 'rounded-xl'
          } overflow-hidden shrink-0 relative bg-black/10 dark:bg-white/5`}
        >
          {icon ? (
            <div className="w-full h-full flex items-center justify-center bg-md-primary-container text-md-on-primary-container">
              <i className={`${icon} text-sm`} />
            </div>
          ) : (
            <M3CoverImage
              src={coverUrl}
              alt={title}
              placeholderType={placeholderType}
              className={`w-10 h-10 ${coverShape === 'circle' ? 'rounded-full' : 'rounded-xl'}`}
              iconClassName="text-base"
            />
          )}
        </div>

        {/* Text Details */}
        <div className="flex flex-col min-w-0 flex-1">
          <span className="font-bold text-xs truncate leading-tight mb-0.5 group-hover:text-md-primary transition-colors duration-150">
            {title}
          </span>
          {subTitle && (
            <span className="text-[11px] text-gray-500 dark:text-gray-400 truncate leading-tight">
              {subTitle}
            </span>
          )}
        </div>
      </div>

      {/* Right Action Slot */}
      <div className="flex items-center space-x-2 shrink-0">
        {badge && (
          <span className="text-[10px] font-bold text-md-primary font-mono hidden sm:inline mr-1">
            {badge.split(' ')[0]}
          </span>
        )}

        {duration && (
          <span className="text-xs text-gray-400 font-mono w-12 text-right hidden sm:inline">
            {duration}
          </span>
        )}

        {onPlay && (
          <button
            onClick={e => {
              e.stopPropagation();
              onPlay(e);
            }}
            className="w-8 h-8 rounded-full hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-center opacity-0 group-hover:opacity-100 transition"
          >
            <i className="fa-solid fa-play text-xs pl-0.5 text-md-primary" />
          </button>
        )}

        {onFavorite && (
          <button
            onClick={e => {
              e.stopPropagation();
              onFavorite(e);
            }}
            className={`w-8 h-8 rounded-full flex items-center justify-center transition ${
              isFavorited
                ? 'text-red-500'
                : 'text-gray-400 opacity-0 group-hover:opacity-100 hover:text-red-400'
            }`}
          >
            <i className="fa-solid fa-heart text-xs" />
          </button>
        )}

        {onDelete && (
          <button
            onClick={e => {
              e.stopPropagation();
              onDelete(e);
            }}
            className="w-8 h-8 rounded-full text-gray-400 hover:text-red-400 flex items-center justify-center opacity-0 group-hover:opacity-100 transition"
          >
            <i className="fa-solid fa-trash-can text-xs" />
          </button>
        )}

        {onMenu && (
          <button
            onClick={e => {
              e.stopPropagation();
              onMenu(e);
            }}
            className="w-8 h-8 rounded-full hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-center opacity-0 group-hover:opacity-100 transition"
          >
            <i className="fa-solid fa-ellipsis-vertical text-xs opacity-70" />
          </button>
        )}

        {showChevron && (
          <i className="fa-solid fa-chevron-right text-xs text-gray-400 opacity-60 group-hover:opacity-100 group-hover:translate-x-0.5 transition" />
        )}

        {customActions}
      </div>
    </div>
  );
};
