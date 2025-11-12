import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { 
  CognitoIdentityProviderClient, 
  InitiateAuthCommand,
  RespondToAuthChallengeCommand,
  ChangePasswordCommand
} from '@aws-sdk/client-cognito-identity-provider';

import AWS_CONFIG from '../config/aws';

const cognitoClient = new CognitoIdentityProviderClient({
  region: AWS_CONFIG.region,
});

interface User {
  username: string;
  email: string;
  accessToken: string;
  idToken: string;
  refreshToken: string;
}

interface AuthContextType {
  user: User | null;
  login: (username: string, password: string) => Promise<void>;
  logout: () => void;
  changePassword: (oldPassword: string, newPassword: string) => Promise<void>;
  completeNewPasswordChallenge: (newPassword: string) => Promise<void>;
  isLoading: boolean;
  challengeData: any; // Pour stocker les données du challenge NEW_PASSWORD_REQUIRED
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [challengeData, setChallengeData] = useState<any>(null);

  useEffect(() => {
    // Vérifier si un token est stocké au démarrage
    const storedUser = localStorage.getItem('claudeUser');
    if (storedUser) {
      try {
        const parsedUser = JSON.parse(storedUser);
        setUser(parsedUser);
      } catch (error) {
        console.error('Error parsing stored user:', error);
        localStorage.removeItem('claudeUser');
      }
    }
    setIsLoading(false);
  }, []);

  const login = async (username: string, password: string) => {
    try {
      setIsLoading(true);
      
      const command = new InitiateAuthCommand({
        AuthFlow: 'USER_PASSWORD_AUTH',
        ClientId: AWS_CONFIG.clientId,
        AuthParameters: {
          USERNAME: username,
          PASSWORD: password,
        },
      });

      const response = await cognitoClient.send(command);
      
      if (response.AuthenticationResult) {
        const userData: User = {
          username,
          email: username, // Assume username is email
          accessToken: response.AuthenticationResult.AccessToken!,
          idToken: response.AuthenticationResult.IdToken!,
          refreshToken: response.AuthenticationResult.RefreshToken!,
        };

        setUser(userData);
        localStorage.setItem('claudeUser', JSON.stringify(userData));
        localStorage.setItem('idToken', response.AuthenticationResult.IdToken!);
      } else if (response.ChallengeName === 'NEW_PASSWORD_REQUIRED') {
        // Stocker les données du challenge pour completer plus tard
        setChallengeData({
          username,
          session: response.Session,
          challengeParameters: response.ChallengeParameters
        });
        throw new Error('NEW_PASSWORD_REQUIRED');
      } else {
        throw new Error('Authentication failed');
      }
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const completeNewPasswordChallenge = async (newPassword: string) => {
    if (!challengeData) {
      throw new Error('No challenge data available');
    }

    try {
      setIsLoading(true);

      const command = new RespondToAuthChallengeCommand({
        ClientId: AWS_CONFIG.clientId,
        ChallengeName: 'NEW_PASSWORD_REQUIRED',
        Session: challengeData.session,
        ChallengeResponses: {
          USERNAME: challengeData.username,
          NEW_PASSWORD: newPassword,
        },
      });

      const response = await cognitoClient.send(command);

      if (response.AuthenticationResult) {
        const userData: User = {
          username: challengeData.username,
          email: challengeData.username,
          accessToken: response.AuthenticationResult.AccessToken!,
          idToken: response.AuthenticationResult.IdToken!,
          refreshToken: response.AuthenticationResult.RefreshToken!,
        };

        setUser(userData);
        localStorage.setItem('claudeUser', JSON.stringify(userData));
        localStorage.setItem('idToken', response.AuthenticationResult.IdToken!);
        setChallengeData(null);
      } else {
        throw new Error('Challenge response failed');
      }
    } catch (error) {
      console.error('Complete new password challenge error:', error);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const changePassword = async (oldPassword: string, newPassword: string) => {
    if (!user?.accessToken) {
      throw new Error('No authenticated user');
    }

    try {
      setIsLoading(true);

      const command = new ChangePasswordCommand({
        AccessToken: user.accessToken,
        PreviousPassword: oldPassword,
        ProposedPassword: newPassword,
      });

      await cognitoClient.send(command);
    } catch (error) {
      console.error('Change password error:', error);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const logout = () => {
    setUser(null);
    setChallengeData(null);
    localStorage.removeItem('claudeUser');
    localStorage.removeItem('idToken');
  };

  const contextValue: AuthContextType = {
    user,
    login,
    logout,
    changePassword,
    completeNewPasswordChallenge,
    isLoading,
    challengeData,
  };

  return (
    <AuthContext.Provider value={contextValue}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}