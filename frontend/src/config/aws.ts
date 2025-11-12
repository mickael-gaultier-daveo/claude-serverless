// Configuration AWS - Utilise les variables d'environnement
export const AWS_CONFIG = {
  region: import.meta.env.VITE_AWS_REGION || 'eu-west-3',
  userPoolId: import.meta.env.VITE_COGNITO_USER_POOL_ID || 'eu-west-3_rF7y3DuCE',
  clientId: import.meta.env.VITE_COGNITO_CLIENT_ID || '7jr75gm6pbl9ci85otdrvqpkv6',
  apiUrl: import.meta.env.VITE_API_URL || 'https://qpq8mdmjg4.execute-api.eu-west-3.amazonaws.com/prod',
};

export default AWS_CONFIG;