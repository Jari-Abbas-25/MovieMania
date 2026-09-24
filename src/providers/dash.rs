use quick_xml::events::Event;
use quick_xml::reader::Reader;

/// Parses a DASH XML MPD manifest and extracts all unique video representation heights,
/// returned as formatted labels sorted highest to lowest (e.g., ["1080p", "720p", "480p"]).
pub fn extract_dash_video_qualities(xml_content: &str) -> Vec<String> {
    let mut reader = Reader::from_str(xml_content);
    reader.config_mut().trim_text(true);
    let mut in_video_adaptation = false;
    let mut heights = Vec::new();

    let mut buf = Vec::new();
    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) | Ok(Event::Empty(ref e)) => {
                let name = e.name();
                if name.as_ref().eq_ignore_ascii_case(b"AdaptationSet") {
                    let mut is_video = false;
                    let mut is_audio = false;
                    for attr in e.attributes().flatten() {
                        let key = attr.key.as_ref();
                        let val = attr.value.as_ref();
                        if key.eq_ignore_ascii_case(b"contentType") {
                            if val.eq_ignore_ascii_case(b"video") {
                                is_video = true;
                            } else if val.eq_ignore_ascii_case(b"audio") {
                                is_audio = true;
                            }
                        }
                        if key.eq_ignore_ascii_case(b"mimeType") {
                            if val.starts_with(b"video/") {
                                is_video = true;
                            } else if val.starts_with(b"audio/") {
                                is_audio = true;
                            }
                        }
                    }
                    if is_audio {
                        in_video_adaptation = false;
                    } else if is_video {
                        in_video_adaptation = true;
                    } else {
                        // Default to video adaptation set if not explicitly marked audio
                        in_video_adaptation = true;
                    }
                } else if name.as_ref().eq_ignore_ascii_case(b"Representation") {
                    let mut height = None;
                    let mut is_explicit_audio = false;
                    for attr in e.attributes().flatten() {
                        let key = attr.key.as_ref();
                        let val = attr.value.as_ref();
                        if key.eq_ignore_ascii_case(b"height") {
                            if let Ok(h_str) = std::str::from_utf8(val) {
                                if let Ok(h) = h_str.parse::<u32>() {
                                    height = Some(h);
                                }
                            }
                        }
                        if key.eq_ignore_ascii_case(b"mimeType") && val.starts_with(b"audio/") {
                            is_explicit_audio = true;
                        }
                    }
                    if !is_explicit_audio && in_video_adaptation {
                        if let Some(h) = height {
                            heights.push(h);
                        }
                    }
                }
            }
            Ok(Event::End(ref e)) => {
                if e.name().as_ref().eq_ignore_ascii_case(b"AdaptationSet") {
                    in_video_adaptation = false;
                }
            }
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
        buf.clear();
    }

    heights.sort_unstable_by(|a, b| b.cmp(a));
    heights.dedup();
    heights.into_iter().map(|h| format!("{h}p")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_dash_qualities_multi_res() {
        let manifest = r#"<?xml version="1.0" encoding="utf-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" minBufferTime="PT10.3S">
    <Period id="0">
        <AdaptationSet id="0" contentType="video" maxWidth="1920" maxHeight="1080">
            <Representation id="0" mimeType="video/mp4" width="1920" height="1080" />
            <Representation id="1" mimeType="video/mp4" width="1280" height="720" />
            <Representation id="2" mimeType="video/mp4" width="854" height="480" />
        </AdaptationSet>
        <AdaptationSet id="1" contentType="audio" lang="hin">
            <Representation id="3" mimeType="audio/mp4" bandwidth="128000" />
        </AdaptationSet>
    </Period>
</MPD>"#;

        let qualities = extract_dash_video_qualities(manifest);
        assert_eq!(qualities, vec!["1080p", "720p", "480p"]);
    }

    #[test]
    fn test_extract_dash_qualities_partial_res() {
        let manifest = r#"<?xml version="1.0" encoding="utf-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011">
    <Period id="0">
        <AdaptationSet id="0" contentType="video">
            <Representation id="1" width="1280" height="720" />
            <Representation id="2" width="854" height="480" />
        </AdaptationSet>
    </Period>
</MPD>"#;

        let qualities = extract_dash_video_qualities(manifest);
        assert_eq!(qualities, vec!["720p", "480p"]);
    }

    #[test]
    fn test_extract_dash_qualities_single_res() {
        let manifest = r#"<?xml version="1.0" encoding="utf-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011">
    <Period id="0">
        <AdaptationSet id="0" contentType="video">
            <Representation id="1" width="1280" height="720" />
        </AdaptationSet>
    </Period>
</MPD>"#;

        let qualities = extract_dash_video_qualities(manifest);
        assert_eq!(qualities, vec!["720p"]);
    }
}
