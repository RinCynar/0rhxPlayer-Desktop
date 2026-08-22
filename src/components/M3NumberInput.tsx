import { useState, useEffect } from 'react';

export interface M3NumberInputProps {
  value: number;
  onChange: (val: number) => void;
  min?: number;
  max?: number;
  step?: number;
  unit?: string;
  precision?: number;
  className?: string;
  inputClassName?: string;
  onDoubleClick?: () => void;
  title?: string;
  disabled?: boolean;
}

export function M3NumberInput({
  value,
  onChange,
  min = -Infinity,
  max = Infinity,
  unit,
  precision = 1,
  className = '',
  inputClassName = '',
  onDoubleClick,
  title,
  disabled = false,
}: M3NumberInputProps) {
  const [text, setText] = useState<string>(() => {
    return precision > 0 ? value.toFixed(precision) : String(value);
  });
  const [isFocused, setIsFocused] = useState(false);

  useEffect(() => {
    if (!isFocused) {
      setText(precision > 0 ? value.toFixed(precision) : String(value));
    }
  }, [value, precision, isFocused]);

  const commitValue = () => {
    let parsed = parseFloat(text);
    if (isNaN(parsed)) {
      parsed = value;
    }
    const clamped = Math.max(min, Math.min(max, parsed));
    onChange(clamped);
    setText(precision > 0 ? clamped.toFixed(precision) : String(clamped));
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      commitValue();
      (e.target as HTMLInputElement).blur();
    } else if (e.key === 'Escape') {
      setText(precision > 0 ? value.toFixed(precision) : String(value));
      (e.target as HTMLInputElement).blur();
    }
  };

  return (
    <div
      onDoubleClick={onDoubleClick}
      title={title}
      className={`inline-flex items-center justify-center bg-black/10 dark:bg-white/10 rounded-xl px-2 py-1 transition border border-transparent focus-within:border-md-primary focus-within:ring-1 focus-within:ring-md-primary ${className}`}
    >
      <input
        type="number"
        value={text}
        disabled={disabled}
        onChange={(e) => setText(e.target.value)}
        onFocus={() => setIsFocused(true)}
        onBlur={() => {
          setIsFocused(false);
          commitValue();
        }}
        onKeyDown={handleKeyDown}
        className={`bg-transparent text-center font-bold text-xs outline-none w-12 text-gray-900 dark:text-gray-100 ${inputClassName}`}
      />
      {unit && (
        <span className="text-[10px] text-gray-400 select-none pl-0.5">{unit}</span>
      )}
    </div>
  );
}