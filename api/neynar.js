const axios = require('axios');

const NEYNAR_API_KEY = process.env.NEYNAR_API_KEY;
const NEYNAR_CLIENT_ID = process.env.NEYNAR_CLIENT_ID;
const NEYNAR_CLIENT_SECRET = process.env.NEYNAR_CLIENT_SECRET;

// Get auth URL
export async function getAuthUrl(req, res) {
    try {
        const { clientId, redirectUrl } = req.body;
        
        const authUrl = `https://app.neynar.com/api/oauth/authorize?client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUrl)}&response_type=code&scope=openid%20offline_access`;
        
        res.json({ authUrl });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
}

// Exchange code for token
export async function getToken(req, res) {
    try {
        const { code } = req.body;
        
        const response = await axios.post('https://app.neynar.com/api/oauth/token', {
            client_id: NEYNAR_CLIENT_ID,
            client_secret: NEYNAR_CLIENT_SECRET,
            code,
            grant_type: 'authorization_code'
        });

        const { access_token, refresh_token } = response.data;

        // Get user info
        const userResponse = await axios.get('https://api.neynar.com/v2/farcaster/user/me', {
            headers: {
                'X-API-KEY': NEYNAR_API_KEY,
                'Authorization': `Bearer ${access_token}`
            }
        });

        const user = userResponse.data.user;

        res.json({
            user: {
                fid: user.fid,
                username: user.username,
                pfpUrl: user.pfp_url,
                signer: user.custody_address
            }
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
}
