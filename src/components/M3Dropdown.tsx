import { useState, useRef, useEffect } from 'react';

import { usePlayer } from '../context/PlayerContext';

export interface DropdownOption<T extends string | number> {
  value: T;
  label: string;
  subLabel?: string;
  icon?: string;
}

export interface M3DropdownProps<T extends string | number> {
  value: T;
  onChange: (value: T) => void;
  options: DropdownOption<T>[];
  label?: string;
  placeholder?: string;
  className?: string;
  buttonClassName?: string;
  align?: 'left' | 'right';
  disabled?: boolean;
}

export function M3Dropdown<T extends string | number>({
  value,
  onChange,
  options,
  label,
  placeholder,
  className = '',
  buttonClassName = '',
  align = 'right',
  disabled = false,
}: M3DropdownProps<T>) {
  const { isDarkMode, lang } = usePlayer();
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const defaultPlaceholder = lang === 'en' ? 'Select...' : lang === 'ja' ? '選択してください...' : '请选择...';
  const effectivePlaceholder = placeholder ?? defaultPlaceholder;
  const selectedOption = options.find((opt) => opt.value === value);


  // Close dropdown on outside click or Esc key
  useEffect(() => {
    const handleOutsideClick = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setIsOpen(false);
      }
    };

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setIsOpen(false);
      }
    };

    if (isOpen) {
      document.addEventListener('mousedown', handleOutsideClick);
      document.addEventListener('keydown', handleKeyDown);
    }

    return () => {
      document.removeEventListener('mousedown', handleOutsideClick);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen]);

  const panelBg = isDarkMode ? 'bg-[#1E1D24] border-white/10' : 'bg-white border-black/10 shadow-2xl';
  const buttonBg = isDarkMode
    ? 'bg-white/5 hover:bg-white/10 text-gray-200 border-white/5'
    : 'bg-black/5 hover:bg-black/10 text-gray-800 border-black/5';

  return (
    <div ref={dropdownRef} className={`relative inline-block text-left ${className}`}>
      {label && <div className="text-xs font-semibold text-gray-400 mb-1">{label}</div>}

      {/* Dropdown trigger button */}
      <button
        type="button"
        disabled={disabled}
        onClick={() => setIsOpen(!isOpen)}
        className={`flex items-center justify-between gap-2.5 px-3.5 py-2 rounded-2xl text-xs font-medium border transition-all duration-200 outline-none focus:ring-2 focus:ring-[#39C5BB] ${buttonBg} ${
          disabled ? 'opacity-40 cursor-not-allowed' : 'cursor-pointer'
        } ${buttonClassName}`}
      >
        <span className="flex items-center gap-2 truncate">
          {selectedOption?.icon && <i className={`fa-solid ${selectedOption.icon} text-xs opacity-70`} />}
          <span className="truncate">{selectedOption ? selectedOption.label : effectivePlaceholder}</span>
        </span>

        <i
          className={`fa-solid fa-chevron-down text-[10px] opacity-60 transition-transform duration-200 ${
            isOpen ? 'rotate-180' : 'rotate-0'
          }`}
        />
      </button>

      {/* Dropdown panel */}
      {isOpen && (
        <div
          className={`absolute ${
            align === 'right' ? 'right-0' : 'left-0'
          } mt-2 min-w-[180px] max-w-[280px] w-max max-h-64 overflow-y-auto rounded-2xl border p-1.5 z-50 shadow-2xl animate-fade-in ${panelBg}`}
        >
          {options.map((opt) => {
            const isSelected = opt.value === value;
            return (
              <button
                key={String(opt.value)}
                type="button"
                onClick={() => {
                  onChange(opt.value);
                  setIsOpen(false);
                }}
                className={`w-full flex items-center justify-between gap-3 px-3 py-2 rounded-xl text-left text-xs transition duration-150 ${
                  isSelected
                    ? isDarkMode
                      ? 'bg-[#39C5BB]/20 text-[#39C5BB] font-semibold'
                      : 'bg-[#39C5BB]/15 text-[#006A6B] font-semibold'
                    : isDarkMode
                    ? 'hover:bg-white/5 text-gray-200'
                    : 'hover:bg-black/5 text-gray-800'
                }`}
              >
                <div className="flex items-center gap-2.5 truncate min-w-0">
                  {opt.icon && <i className={`fa-solid ${opt.icon} text-xs opacity-70 shrink-0`} />}
                  <div className="truncate min-w-0">
                    <div className="truncate">{opt.label}</div>
                    {opt.subLabel && (
                      <div className="text-[10px] text-gray-500 truncate mt-0.5">{opt.subLabel}</div>
                    )}
                  </div>
                </div>

                {isSelected && (
                  <i className="fa-solid fa-check text-[11px] text-[#39C5BB] shrink-0" />
                )}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}