package net.plataapp.plata;

import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.util.Base64;

import androidx.biometric.BiometricManager;
import androidx.biometric.BiometricPrompt;
import androidx.core.content.ContextCompat;
import androidx.core.content.IntentCompat;
import androidx.fragment.app.FragmentActivity;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;

/**
 * Lo único que Plata necesita del sistema y que Capacitor no trae:
 *  - biometricAvailable / biometricAuth: huella o rostro para abrir la app (el PIN de la web sigue siendo el respaldo);
 *  - getShared: lo que la persona mandó a Plata desde «Compartir» en otra app (una captura, un archivo o un texto), que la web lee al abrir.
 * Nada sale del teléfono: la huella la resuelve el sistema y lo compartido queda en memoria hasta que la web lo recoge.
 */
@CapacitorPlugin(name = "PlataNative")
public class PlataNativePlugin extends Plugin {
    private static final long MAX_SHARED_BYTES = 15L * 1024 * 1024;
    private static JSObject pendingShare = null;

    @PluginMethod
    public void biometricAvailable(PluginCall call) {
        int r = BiometricManager.from(getContext()).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK);
        JSObject o = new JSObject();
        o.put("available", r == BiometricManager.BIOMETRIC_SUCCESS);
        call.resolve(o);
    }

    @PluginMethod
    public void biometricAuth(final PluginCall call) {
        final FragmentActivity activity = getActivity();
        if (activity == null) {
            JSObject o = new JSObject();
            o.put("ok", false);
            call.resolve(o);
            return;
        }
        final String title = call.getString("title", "Abrir Plata");
        final String subtitle = call.getString("subtitle", "");
        final String cancel = call.getString("cancel", "Cancelar");
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                BiometricPrompt prompt = new BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), new BiometricPrompt.AuthenticationCallback() {
                    @Override
                    public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult result) {
                        JSObject o = new JSObject();
                        o.put("ok", true);
                        call.resolve(o);
                    }

                    @Override
                    public void onAuthenticationError(int errorCode, CharSequence errString) {
                        JSObject o = new JSObject();
                        o.put("ok", false);
                        o.put("code", errorCode);
                        call.resolve(o);
                    }
                });
                BiometricPrompt.PromptInfo.Builder info = new BiometricPrompt.PromptInfo.Builder()
                        .setTitle(title)
                        .setNegativeButtonText(cancel)
                        .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_WEAK);
                if (subtitle != null && !subtitle.isEmpty()) info.setSubtitle(subtitle);
                prompt.authenticate(info.build());
            }
        });
    }

    @PluginMethod
    public void getShared(PluginCall call) {
        JSObject r = new JSObject();
        JSObject item = pendingShare;
        pendingShare = null;
        if (item != null) r.put("item", item);
        call.resolve(r);
    }

    /** Guarda lo que llegó por «Compartir» (ACTION_SEND) hasta que la web lo pida. Archivos de hasta 15 MB. */
    static void stash(Context context, Intent intent) {
        if (intent == null || !Intent.ACTION_SEND.equals(intent.getAction())) return;
        String type = intent.getType();
        if (type == null) return;
        try {
            JSObject o = new JSObject();
            Uri uri = IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri.class);
            if (uri != null) {
                ContentResolver cr = context.getContentResolver();
                String name = "compartido";
                Cursor c = cr.query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null);
                if (c != null) {
                    try {
                        if (c.moveToFirst() && c.getString(0) != null) name = c.getString(0);
                    } finally {
                        c.close();
                    }
                }
                InputStream in = cr.openInputStream(uri);
                if (in == null) return;
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                try {
                    byte[] buf = new byte[16384];
                    int n;
                    long total = 0;
                    while ((n = in.read(buf)) > 0) {
                        total += n;
                        if (total > MAX_SHARED_BYTES) return;
                        out.write(buf, 0, n);
                    }
                } finally {
                    in.close();
                }
                o.put("kind", "file");
                o.put("name", name);
                o.put("mime", type);
                o.put("data", Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP));
            } else {
                String text = intent.getStringExtra(Intent.EXTRA_TEXT);
                if (text == null) return;
                o.put("kind", "text");
                o.put("mime", type);
                o.put("text", text);
            }
            pendingShare = o;
        } catch (Exception e) {
            // lo compartido no se pudo leer: no se guarda nada
        }
    }
}
