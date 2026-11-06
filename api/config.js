module.exports = function handler(req, res) {
 const url = process.env.SUPABASE_URL;
 const key = process.env.SUPABASE_PUBLISHABLE_KEY;
 res.setHeader('Cache-Control', 'no-store');
 if (!url || !key || !(key.startsWith('sb_publishable_') || key.startsWith('eyJ'))) return res.status(503).json({error:'Missing public configuration'});
 if(key.startsWith('eyJ')) {try {const claim=JSON.parse(Buffer.from(key.split('.')[1], 'base64url').toString());if(claim.role!=='anon')return res.status(503).json({error:'Public key required'});}catch{return res.status(503).json({error:'Invalid public key'});}}
 return res.status(200).json({url:url.replace(/\/$/, ''),key});
};
