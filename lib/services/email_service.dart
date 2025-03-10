import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/team_model.dart';
import 'package:intl/intl.dart';

class EmailService {
  // Clé API Brevo
  static const String apiKey = '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';
  static const String apiUrl = 'https://api.brevo.com/v3/smtp/email';

  // Méthode pour envoyer un email simple
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String htmlContent,
    String senderName = 'WebXIO',
    String senderEmail = 'echiyahya@live.fr',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'accept': 'application/json',
          'api-key': apiKey,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'sender': {
            'name': senderName,
            'email': senderEmail,
          },
          'to': [
            {
              'email': to,
            }
          ],
          'subject': subject,
          'htmlContent': htmlContent,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('Email envoyé avec succès à $to');
        return true;
      } else {
        print('Erreur lors de l\'envoi de l\'email: ${response.statusCode}');
        print('Réponse: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception lors de l\'envoi de l\'email: $e');
      return false;
    }
  }

  // Méthode pour envoyer un email d'invitation
  static Future<bool> sendInvitationEmail({
    required String to,
    required String teamName,
    required String inviterName,
    required String token,
    required String teamId,
  }) async {
    // Générer l'URL d'invitation pour application mobile
    final invitationUrl = 'webxio://invitation?token=$token&team=$teamId';

    // Créer le contenu HTML
    final htmlContent = '''
    <h2>Vous avez été invité à rejoindre l'équipe $teamName</h2>
    <p>$inviterName vous a invité à rejoindre leur équipe sur l'application WebXIO.</p>
    <p>Pour accepter cette invitation, veuillez ouvrir ce lien sur votre appareil où l'application WebXIO est installée :</p>
    <p><a href="$invitationUrl">Accepter l'invitation</a></p>
    <p>Si le lien ne fonctionne pas directement, vous pouvez copier le code d'invitation suivant et l'utiliser dans l'application :</p>
    <p><strong>Code d'invitation:</strong> $token</p>
    <p><strong>ID d'équipe:</strong> $teamId</p>
    <p>Ce lien expirera dans 7 jours.</p>
    <p>Si vous n'avez pas demandé cette invitation, vous pouvez ignorer cet email.</p>
    ''';

    // Sujet de l'email
    final subject = 'Invitation à rejoindre l\'équipe $teamName';

    // Envoyer l'email
    return sendEmail(
      to: to,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  // Méthode pour envoyer un email d'invitation à partir d'un objet Invitation
  static Future<bool> sendInvitationEmailFromInvitation(Invitation invitation) async {
    try {
      final senderEmail = 'echiyahya@live.fr';
      final senderName = 'WebXIO App';
      
      // Générer le lien avec un schéma personnalisé pour les appareils mobiles
      final invitationLink = 'webxio://invitation?token=${invitation.token}&team=${invitation.teamId}';
      
      // Contenu HTML de l'email avec plus d'informations et de style
      final htmlContent = '''
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 5px;">
        <h2 style="color: #1F4E5F;">Invitation à rejoindre une équipe sur WebXIO</h2>
        <p>Bonjour,</p>
        <p>Vous avez été invité(e) à rejoindre l'équipe <strong>${invitation.teamName ?? 'sur WebXIO'}</strong>.</p>
        
        <div style="margin: 30px 0; text-align: center;">
          <a href="$invitationLink" style="display: inline-block; background-color: #1F4E5F; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; font-weight: bold;">Accepter l'invitation</a>
        </div>
        
        <p style="margin-top: 20px;"><strong>Si le bouton ne fonctionne pas :</strong></p>
        <p>Vous pouvez également ouvrir l'application WebXIO et saisir manuellement le code d'invitation suivant :</p>
        
        <div style="background-color: #f5f5f5; padding: 12px; border-radius: 4px; margin: 15px 0; text-align: center; font-family: monospace; font-size: 18px; letter-spacing: 2px;">
          <strong>${invitation.token}</strong>
        </div>
        
        <p><strong>Informations supplémentaires :</strong></p>
        <ul>
          <li>Token: ${invitation.token}</li>
          <li>ID de l'équipe: ${invitation.teamId}</li>
          <li>Cette invitation expirera le ${DateFormat('yyyy-MM-dd à HH:mm').format(invitation.expiresAt ?? DateTime.now().add(const Duration(days: 7)))}</li>
        </ul>
        
        <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
        <p style="color: #999; font-size: 12px;">Ce message a été envoyé automatiquement par WebXIO. Merci de ne pas y répondre.</p>
      </div>
      ''';
      
      // Texte brut de l'email (pour les clients qui ne prennent pas en charge le HTML)
      final textContent = '''
      Invitation à rejoindre une équipe sur WebXIO
      
      Bonjour,
      
      Vous avez été invité(e) à rejoindre l'équipe ${invitation.teamName ?? 'sur WebXIO'}.
      
      Pour accepter l'invitation, veuillez cliquer sur ce lien ou le copier dans votre navigateur :
      $invitationLink
      
      Si le lien ne fonctionne pas, vous pouvez également ouvrir l'application WebXIO et saisir manuellement le code d'invitation suivant :
      ${invitation.token}
      
      Informations supplémentaires :
      - Token: ${invitation.token}
      - ID de l'équipe: ${invitation.teamId}
      - Cette invitation expirera le ${DateFormat('yyyy-MM-dd à HH:mm').format(invitation.expiresAt ?? DateTime.now().add(const Duration(days: 7)))}
      
      Ce message a été envoyé automatiquement par WebXIO. Merci de ne pas y répondre.
      ''';
      
      // Envoyer l'email
      return sendEmail(
        to: invitation.email,
        subject: 'Invitation à rejoindre l\'équipe ${invitation.teamName}',
        htmlContent: htmlContent,
      );
    } catch (e) {
      print('Exception lors de l\'envoi de l\'email: $e');
      return false;
    }
  }
}
