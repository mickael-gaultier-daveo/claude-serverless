// Configuration des domaines autorisés
export const ALLOWED_ORIGINS = [
  'https://claude-serverless.daveo-dev.fr',
  // CloudFront domain sera ajouté automatiquement après le déploiement
] as const;

// Détection automatique du domaine courant
export const getCurrentDomain = (): string => {
  if (typeof window !== 'undefined') {
    return window.location.origin;
  }
  return 'http://localhost:3000';
};

// Vérification si le domaine courant est autorisé
export const isAllowedOrigin = (origin?: string): boolean => {
  const currentOrigin = origin || getCurrentDomain();
  
  return ALLOWED_ORIGINS.some(allowedOrigin => 
    currentOrigin === allowedOrigin ||
    currentOrigin.endsWith('.cloudfront.net') ||
    currentOrigin.includes('localhost')
  );
};

export default {
  ALLOWED_ORIGINS,
  getCurrentDomain,
  isAllowedOrigin,
};