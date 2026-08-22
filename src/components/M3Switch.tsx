import React from 'react';

export interface M3SwitchProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
  className?: string;
}

export const M3Switch: React.FC<M3SwitchProps> = ({
  checked,
  onChange,
  disabled = false,
  className = '',
}) => {
  return (
    <label
      className={`relative inline-flex items-center select-none ${
        disabled ? 'opacity-40 cursor-not-allowed' : 'cursor-pointer'
      } ${className}`}
      onClick={(e) => {
        // Prevent click inside switch from bubbling to parent clickable row and causing double-toggle
        e.stopPropagation();
      }}
    >
      {/* 原生隐藏 Checkbox，承接全部真实点击事件 */}
      <input
        type="checkbox"
        checked={checked}
        disabled={disabled}
        onChange={(e) => onChange(e.target.checked)}
        className="sr-only"
      />
      {/* 胶囊轨道 Track */}
      <div
        className={`w-[52px] h-8 rounded-full transition-colors duration-200 p-1 flex items-center ${
          checked
            ? 'bg-md-primary'
            : 'bg-md-surface-container-highest border-2 border-md-outline'
        }`}
      >
        {/* 滑块 Thumb：强制 pointer-events-none 避免拦截事件 */}
        <div
          className={`w-6 h-6 rounded-full transition-all duration-200 pointer-events-none shadow-sm ${
            checked
              ? 'translate-x-[20px] bg-md-on-primary'
              : 'translate-x-0 bg-md-outline'
          }`}
        />
      </div>
    </label>
  );
};

export default M3Switch;
