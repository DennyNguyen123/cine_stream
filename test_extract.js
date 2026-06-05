sync function testPhimMoiChill() {
  const headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
  };

  async function getEmbed(slug, ep, server) {
    const res = await fetch(`https://phimmoichill.live/xem-phim/${slug}/${ep}/vietsub?server=${server}`, { headers });
    const html = await res.text();

    const m3u8Regex = /link_m3u8[\\":]+(https?[^"\\]+m3u8)/;
    const m3Match = html.match(m3u8Regex);
    if (m3Match) {
      console.log(`M3U8 for ${ep} [${server}]:`, m3Match[1].replace(/\\\//g, '/'));
      return m3Match[1];
    }

    const scriptRegex = /<script>self\.__next_f\.push\(\[1,"(.*?)"\]\)<\/script>/g;
    let fullPayload = '';
    let match;
    while ((match = scriptRegex.exec(html)) !== null) {
      let str = match[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\');
      fullPayload += str;
    }
    const epSourceRegex = /"episode_sources":(\[.*?\])/;
    const sourceMatch = fullPayload.match(epSourceRegex);
    if (sourceMatch) {
      const sources = JSON.parse(sourceMatch[1]);
      const target = sources.find(s => s.server?.slug === server);
      if (target && target.link) {
        console.log(`JSON Link for ${ep} [${server}]:`, target.link);
        return target.link;
      }
    }

    const embedRegex = /https?[^"\\]+embed[^"\\]+/g;
    const matches = html.match(embedRegex);
    console.log(`Embed for ${ep} [${server}]:`, matches);
    return matches;
  }

  await getEmbed('dao-hai-tac', 'tap-800', 'kk');
  await getEmbed('dao-hai-tac', 'tap-801', 'kk');
}

testPhimMoiChill();
