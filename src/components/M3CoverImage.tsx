import React, { useState } from 'react';
import { getCoverSrc } from '../utils/assetUrl';
import { M3CoverPlaceholder, PlaceholderIconType } from './M3CoverPlaceholder';

interface M3CoverImageProps {
  src?: string | null;
  alt?: string;
  className?: string;
  placeholderType?: PlaceholderIconType;
  iconClassName?: string;
  imageClassName?: string;
}

export const M3CoverImage: React.FC<M3CoverImageProps> = ({
  src,
  alt = 'Cover',
  className = 'w-full h-full aspect-square rounded-2xl',
  placeholderType = 'music',
  iconClassName,
  imageClassName = '',
}) => {
  const [hasError, setHasError] = useState(false);
  const coverSrc = getCoverSrc(src);

  if (!coverSrc || hasError) {
    return (
      <M3CoverPlaceholder
        type={placeholderType}
        className={className}
        iconClassName={iconClassName}
      />
    );
  }

  return (
    <div className={`relative overflow-hidden ${className}`}>
      <img
        src={coverSrc}
        alt={alt}
        decoding="async"
        onError={() => setHasError(true)}
        className={`w-full h-full object-cover transition-opacity duration-200 ${imageClassName}`}
      />
    </div>
  );
};
