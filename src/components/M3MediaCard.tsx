import React from 'react';
import { M3CoverImage } from './M3CoverImage';

export interface M3MediaCardProps {
  type?: 'square' | 'circle';
  coverUrl?: string;
  placeholderType?: 'music' | 'album' | 'artist' | 'folder';
  title: string;
  subTitle?: string;
  badge?: string;
  bottomBadge?: string;
  isSelected?: boolean;
  isSelectMode?: boolean;
  onSelectToggle?: (e: React.MouseEvent) => void;
  onClick?: () => void;
  onPlay?: (e: React.MouseEvent) => void;
  isFavorited?: boolean;
  onFavorite?: (e: React.MouseEvent) => void;
  onMenu?: (e: React.MouseEvent) => void;
  customActions?: React.ReactNode;
  icon?: string;
  iconBgClass?: string;
  className?: string;
}

export const M3MediaCard: React.FC<M3MediaCardProps> = ({
  type = 'square',
  coverUrl,
  placeholderType = 'music',
  title,
  subTitle,
  badge,
  bottomBadge,
  isSelected = false,
  isSelectMode = false,
  onSelectToggle,
  onClick,
  onPlay,
  isFavorited,
  onFavorite,
  onMenu,
  customActions,
  icon,
  iconBgClass,
  className = '',
}) => {
  const cardBg = `bg-md-surface-container hover:bg-md-surface-container-high shadow-sm transition-all duration-200 ${
    isSelected ? 'ring-2 ring-md-primary bg-md-surface-container-highest' : ''
  }`;

  if (type === 'circle') {
    return (
      <div
        onClick={onClick}
        className={`${cardBg} p-4 rounded-3xl cursor-pointer group flex flex-col items-center text-center hover:scale-[1.02] relative ${className}`}
      >
        <div className="w-24 h-24 rounded-full overflow-hidden mb-3 relative">
          <M3CoverImage
            src={coverUrl}
            alt={title}
            placeholderType="artist"
            className="w-24 h-24 rounded-full"
            iconClassName="text-2xl"
            imageClassName="group-hover:scale-105 transition-transform duration-300"
          />
          {onPlay && (
            <div
              onClick={e => {
                e.stopPropagation();
                onPlay(e);
              }}
              className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center transition"
            >
              <div className="w-9 h-9 rounded-full bg-md-primary text-md-on-primary flex items-center justify-center shadow-lg">
                <i className="fa-solid fa-play text-xs pl-0.5" />
              </div>
            </div>
          )}
        </div>
        <div className="w-full">
          <div className="font-bold text-xs truncate transition group-hover:text-md-primary leading-tight mb-1">{title}</div>
          {subTitle && <div className="text-[11px] text-gray-500 dark:text-gray-400 truncate leading-tight">{subTitle}</div>}
        </div>
        {customActions}
      </div>
    );
  }

  return (
    <div
      onClick={onClick}
      className={`${cardBg} p-3.5 rounded-3xl cursor-pointer group flex flex-col justify-between hover:scale-[1.02] relative ${className}`}
    >
      <div className="aspect-square rounded-2xl overflow-hidden mb-2.5 relative">
        {icon ? (
          <div
            className={`w-full h-full flex items-center justify-center ${
              iconBgClass || 'bg-md-primary-container text-md-on-primary-container'
            } group-hover:scale-105 transition-transform duration-300`}
          >
            <i className={`${icon} text-3xl opacity-80`} />
          </div>
        ) : (
          <M3CoverImage
            src={coverUrl}
            alt={title}
            placeholderType={placeholderType}
            imageClassName="group-hover:scale-105 transition-transform duration-300"
          />
        )}

        {/* Checkbox for select mode */}
        {isSelectMode && onSelectToggle && (
          <div
            onClick={e => {
              e.stopPropagation();
              onSelectToggle(e);
            }}
            className="absolute top-2 left-2 z-10 w-6 h-6 rounded-full bg-black/60 backdrop-blur-xs flex items-center justify-center"
          >
            <input
              type="checkbox"
              checked={isSelected}
              onChange={() => {}}
              className="w-4 h-4 accent-md-primary rounded cursor-pointer"
            />
          </div>
        )}

        {/* Top-right format badge */}
        {badge && !isSelectMode && (
          <span className="absolute top-2 right-2 px-1.5 py-0.5 text-[9px] font-bold bg-black/60 backdrop-blur-md rounded-md text-amber-300">
            {badge.split(' ')[0]}
          </span>
        )}

        {/* Bottom-left count badge */}
        {bottomBadge && (
          <span className="absolute bottom-2 left-2 text-white text-[10px] font-semibold bg-black/50 backdrop-blur-xs px-2 py-0.5 rounded-md">
            {bottomBadge}
          </span>
        )}

        {/* Hover Action Buttons */}
        {!isSelectMode && (
          <>
            {onMenu && (
              <button
                onClick={e => {
                  e.stopPropagation();
                  onMenu(e);
                }}
                className="absolute bottom-2 right-2 w-7 h-7 rounded-full bg-black/50 text-white flex items-center justify-center opacity-0 group-hover:opacity-100 hover:bg-black/80 transition backdrop-blur-xs z-10"
              >
                <i className="fa-solid fa-ellipsis-vertical text-[11px]" />
              </button>
            )}

            {onFavorite && (
              <button
                onClick={e => {
                  e.stopPropagation();
                  onFavorite(e);
                }}
                className={`absolute bottom-2 left-2 w-7 h-7 rounded-full bg-black/50 flex items-center justify-center transition backdrop-blur-xs z-10 ${
                  isFavorited ? 'text-red-500 opacity-100' : 'text-white opacity-0 group-hover:opacity-100 hover:text-red-400'
                }`}
              >
                <i className="fa-solid fa-heart text-[11px]" />
              </button>
            )}

            {onPlay && !onFavorite && (
              <div
                onClick={e => {
                  e.stopPropagation();
                  onPlay(e);
                }}
                className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center transition"
              >
                <div className="w-9 h-9 rounded-full bg-md-primary text-md-on-primary flex items-center justify-center shadow-lg">
                  <i className="fa-solid fa-play text-xs pl-0.5" />
                </div>
              </div>
            )}
          </>
        )}

        {customActions}
      </div>

      <div>
        <div className="font-bold text-xs truncate transition group-hover:text-md-primary leading-tight mb-1">{title}</div>
        {subTitle && <div className="text-[11px] text-gray-500 dark:text-gray-400 truncate leading-tight">{subTitle}</div>}
      </div>
    </div>
  );
};
