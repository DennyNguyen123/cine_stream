use reqwest::Client;
use std::time::Duration;

#[tokio::main]
async fn main() {
    let client = Client::builder()
        .timeout(Duration::from_secs(10))
        .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        .build()
        .unwrap();

    let url = "https://vidsrc.me/embed/movie/tt0111161";
    println!("Fetching {}", url);
    let res = client.get(url).send().await;
    
    match res {
        Ok(r) => {
            println!("Status: {}", r.status());
            let html = r.text().await.unwrap_or_default();
            std::fs::write("vidsrc_dump.html", html).unwrap();
            println!("Dumped to vidsrc_dump.html");
        }
        Err(e) => {
            println!("Error: {}", e);
        }
    }
}
