pub mod lyrics;
pub mod parser;

pub use lyrics::{get_lyrics_for_track, parse_lrc, LyricLine};
pub use parser::{
    fast_metadata, parse_metadata, scan_directory_async, scan_files_async,
    ScanBatchPayload, ScanFinishPayload, TrackMetadata,
};

