import xml.etree.ElementTree as ET
import subprocess

messages_zh = {
    'M3ContextMenu': {
        'Insert to Queue': '插入播放队列',
        'Favorite': '收藏',
        'Add to Playlist...': '加入歌单...',
        'Remove from Playlist': '从歌单中移除',
        'Delete': '删除',
        'Track Details': '详细信息',
        'Open in File Explorer': '在文件资源管理器中打开'
    },
    'PlaylistsView': {
        'Title (A-Z)': '曲名 (A-Z)',
        'Title (Z-A)': '曲名 (Z-A)',
        'Artist (A-Z)': '艺术家 (A-Z)',
        'Artist (Z-A)': '艺术家 (Z-A)',
        'Album (A-Z)': '专辑 (A-Z)',
        'Album (Z-A)': '专辑 (Z-A)',
        'Date Added (New-Old)': '添加时间 (从新到旧)',
        'Date Added (Old-New)': '添加时间 (从旧到新)',
        'Date Modified (New-Old)': '修改时间 (从新到旧)',
        'Date Modified (Old-New)': '修改时间 (从旧到新)',
        'Bitrate (High-Low)': '比特率 (高-低)',
        'Bitrate (Low-High)': '比特率 (低-高)',
        'Duration (Long)': '时长 (长-短)',
        'Duration (Short)': '时长 (短-长)',
        'File Size (Large-Small)': '文件体积 (大-小)',
        'File Size (Small-Large)': '文件体积 (小-大)'
    }
}

messages_ja = {
    'M3ContextMenu': {
        'Insert to Queue': '再生キューに追加',
        'Favorite': 'お気に入り',
        'Add to Playlist...': 'プレイリストに追加...',
        'Remove from Playlist': 'プレイリストから削除',
        'Delete': '削除',
        'Track Details': 'トラックの詳細',
        'Open in File Explorer': 'エクスプローラーで表示'
    },
    'PlaylistsView': {
        'Title (A-Z)': 'タイトル (A-Z)',
        'Title (Z-A)': 'タイトル (Z-A)',
        'Artist (A-Z)': 'アーティスト (A-Z)',
        'Artist (Z-A)': 'アーティスト (Z-A)',
        'Album (A-Z)': 'アルバム (A-Z)',
        'Album (Z-A)': 'アルバム (Z-A)',
        'Date Added (New-Old)': '追加日時 (新しい順)',
        'Date Added (Old-New)': '追加日時 (古い順)',
        'Date Modified (New-Old)': '変更日時 (新しい順)',
        'Date Modified (Old-New)': '変更日時 (古い順)',
        'Bitrate (High-Low)': 'ビットレート (高い順)',
        'Bitrate (Low-High)': 'ビットレート (低い順)',
        'Duration (Long)': '再生時間 (長い順)',
        'Duration (Short)': '再生時間 (短い順)',
        'File Size (Large-Small)': 'ファイルサイズ (大きい順)',
        'File Size (Small-Large)': 'ファイルサイズ (小さい順)'
    }
}

def update_ts_file(filepath, ctx_dict):
    tree = ET.parse(filepath)
    root = tree.getroot()

    contexts = {c.find('name').text: c for c in root.findall('context')}

    for ctx_name, msgs in ctx_dict.items():
        if ctx_name not in contexts:
            c = ET.SubElement(root, 'context')
            n = ET.SubElement(c, 'name')
            n.text = ctx_name
            contexts[ctx_name] = c
        c = contexts[ctx_name]

        existing_sources = {m.find('source').text: m for m in c.findall('message')}
        for src, trans_text in msgs.items():
            if src in existing_sources:
                t = existing_sources[src].find('translation')
                t.text = trans_text
                if 'type' in t.attrib:
                    del t.attrib['type']
            else:
                m = ET.SubElement(c, 'message')
                s = ET.SubElement(m, 'source')
                s.text = src
                t = ET.SubElement(m, 'translation')
                t.text = trans_text

    tree.write(filepath, encoding='utf-8', xml_declaration=True)
    print(f"Updated {filepath}")

update_ts_file('translations/0rhxplayer_zh_CN.ts', messages_zh)
update_ts_file('translations/0rhxplayer_ja_JP.ts', messages_ja)

lrelease = r"C:\Users\RinCynar\Qt\6.11.2\mingw_64\bin\lrelease.exe"
subprocess.run([lrelease, "translations/0rhxplayer_zh_CN.ts", "-qm", "translations/0rhxplayer_zh_CN.qm"], check=True)
subprocess.run([lrelease, "translations/0rhxplayer_ja_JP.ts", "-qm", "translations/0rhxplayer_ja_JP.qm"], check=True)
print("lrelease finished successfully.")
