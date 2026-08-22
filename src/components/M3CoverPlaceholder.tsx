import React from 'react';

export type PlaceholderIconType = 'music' | 'disc' | 'artist' | 'album' | 'folder' | 'heart';

interface M3CoverPlaceholderProps {
  type?: PlaceholderIconType;
  className?: string;
  iconClassName?: string;
}

export const M3CoverPlaceholder: React.FC<M3CoverPlaceholderProps> = ({
  type = 'music',
  className = 'w-full h-full aspect-square rounded-2xl',
  iconClassName,
}) => {
  const getIcon = () => {
    switch (type) {
      case 'artist':
        return 'fa-solid fa-user';
      case 'album':
      case 'disc':
        return 'fa-solid fa-compact-disc';
      case 'folder':
        return 'fa-solid fa-folder';
      case 'heart':
        return 'fa-solid fa-heart';
      case 'music':
      default:
        return 'fa-solid fa-music';
    }
  };

  return (
    <div
      className={`bg-[var(--md-sys-color-surface-container-high)] flex items-center justify-center select-none overflow-hidden transition-colors duration-200 ${className}`}
    >
      <i
        className={`${getIcon()} text-[var(--md-sys-color-primary)] opacity-60 transition-colors duration-200 ${
          iconClassName || 'text-3xl'
        }`}
      />
    </div>
  );
};
