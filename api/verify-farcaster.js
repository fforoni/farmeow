// Vercel Serverless Function

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { address } = req.body;
  
  // Get Neynar API key from Vercel environment variables
  const NEYNAR_API_KEY = process.env.NEYNAR_API_KEY;

  try {
    const response = await fetch(
      `https://api.neynar.com/v2/farcaster/user/bulk-by-address?addresses=${address}`,
      {
        headers: {
          'api_key': NEYNAR_API_KEY,
          'accept': 'application/json'
        }
      }
    );

    const data = await response.json();
    
    if (data && data[address] && data[address].length > 0) {
      const user = data[address][0];
      return res.status(200).json({
        fid: user.fid,
        username: user.username,
        pfp_url: user.pfp_url
      });
    }
    
    return res.status(404).json({ error: 'No Farcaster profile found' });
    
  } catch (error) {
    console.error('Neynar API error:', error);
    return res.status(500).json({ error: 'Failed to fetch Farcaster profile' });
  }
}
