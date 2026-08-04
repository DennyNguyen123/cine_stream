use reqwest::Client;
use std::time::Duration;

pub async fn fetch_vidsrc_dump(imdb_id: &str) {
    let client = Client::builder()
        .timeout(Duration::from_secs(10))
        .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        .build()
        .unwrap();

    let url = format!("https://peachify.top/embed/movie/{}", imdb_id);
    println!("Fetching {}", url);
    let res = client.get(&url).send().await;
    
    match res {
        Ok(r) => {
            println!("Status: {}", r.status());
            let html = r.text().await.unwrap_or_default();
            std::fs::write("vidsrc_dump.html", &html).unwrap();
            
            // Find iframe
            if let Some(start) = html.find(r#"id="player_iframe" src=""#) {
                let after_src = &html[start + 24..];
                if let Some(end) = after_src.find(r#""#) {
                    let mut iframe_url = after_src[..end].to_string();
                    if iframe_url.starts_with("//") {
                        iframe_url = format!("https:{}", iframe_url);
                    }
                    println!("Found iframe: {}", iframe_url);
                    
                    let res2 = client.get(&iframe_url).header("Referer", &url).send().await.unwrap();
                    let html2 = res2.text().await.unwrap();
                    std::fs::write("vidsrc_rcp_dump.html", &html2).unwrap();
                    println!("Dumped to vidsrc_rcp_dump.html");
                    
                    // Find iframe in html2 (the rcp dump)
                    if let Some(start2) = html2.find(r#"src: '/prorcp/"#) {
                        let after_src2 = &html2[start2 + 14..];
                        if let Some(end2) = after_src2.find(r#"'"#) {
                            let prorcp_path = after_src2[..end2].to_string();
                            let prorcp_url = format!("https://cloudorchestranova.com/prorcp/{}", prorcp_path);
                            println!("Found prorcp: {}", prorcp_url);
                            
                            let res3 = client.get(&prorcp_url).header("Referer", &iframe_url).send().await.unwrap();
                            let html3 = res3.text().await.unwrap();
                            std::fs::write("vidsrc_prorcp_dump.html", html3).unwrap();
                            println!("Dumped to vidsrc_prorcp_dump.html");
                        }
                    }
                }
            }
        }
        Err(e) => {
            println!("Error: {}", e);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_vidsrc_dump() {
        fetch_vidsrc_dump("tt0111161").await;
    }
}
