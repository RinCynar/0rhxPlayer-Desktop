import React from 'react';

export interface M3MediaGridProps {
  children: React.ReactNode;
  className?: string;
}

export const M3MediaGrid: React.FC<M3MediaGridProps> = ({ children, className = '' }) => {
  return (
    <div className={`grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-5 ${className}`}>
      {children}
    </div>
  );
};
