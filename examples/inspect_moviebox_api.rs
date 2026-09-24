use serde_json::Value;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = moviebox_tui::providers::moviebox::client::MovieBoxClient::new();
    client.init().await?;
    
    let subject_id = "5608459269503862552"; // AVENGERS
    println!("=== Fetching play-info for {subject_id} ===");
    let play_info = client.get_play_info(subject_id, 0, 0).await?;
    println!("play_info JSON:\n{}", serde_json::to_string_pretty(&play_info)?);
    
    println!("\n=== Fetching resources for {subject_id} ===");
    let resources = client.get_resources(subject_id, 0, 0, 1, None, 20).await?;
    println!("resources JSON:\n{}", serde_json::to_string_pretty(&resources)?);

    Ok(())
}
