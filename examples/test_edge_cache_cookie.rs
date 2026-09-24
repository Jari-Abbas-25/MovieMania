use base64::Engine;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let raw_cookie = "Edge-Cache-Cookie=urlprefix=aHR0cHM6Ly9zYmNkbjMuaGFrdW5heW1hdGF0YS5jb20vZGFzaC81NjA4NDU5MjY5NTAzODYyNTUyXzBfMF80ODBfaDI2NV8zOTYv:sign=53ea877f7e97dee5e7e84392fde4f00c:t=1789905108";
    
    // Extract base64 prefix
    let prefix_b64 = raw_cookie
        .split("urlprefix=")
        .nth(1)
        .and_then(|s| s.split(':').next())
        .unwrap();
    
    let decoded = base64::engine::general_purpose::STANDARD.decode(prefix_b64)?;
    let base_url = String::from_utf8(decoded)?;
    println!("Decoded base URL: {base_url}");
    
    let client = reqwest::Client::new();
    for suffix in &["index.mpd", "manifest.mpd", "master.mpd", "video.mp4"] {
        let manifest_url = format!("{base_url}{suffix}");
        println!("Trying {manifest_url}...");
        let resp = client
            .get(&manifest_url)
            .header("Cookie", raw_cookie)
            .header("Referer", "https://sportslive.wine")
            .header("User-Agent", "MovieBox/1.0")
            .send()
            .await?;
        println!(" - Status: {}", resp.status());
        if resp.status().is_success() {
            let text = resp.text().await?;
            println!(" - Success! Content (first 200 chars):\n{}", &text[..std::cmp::min(200, text.len())]);
            break;
        }
    }
    
    Ok(())
}
