package net.plataapp.plata;

import android.content.Intent;
import android.os.Bundle;

import com.getcapacitor.BridgeActivity;

/** La actividad de Plata: la de Capacitor, más el plugin propio (huella o rostro y recibir desde «Compartir»). */
public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(PlataNativePlugin.class);
        super.onCreate(savedInstanceState);
        // solo al abrir de cero: si la pantalla se gira o se recrea, el mismo «compartir» no se procesa dos veces
        if (savedInstanceState == null) PlataNativePlugin.stash(this, getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        PlataNativePlugin.stash(this, intent);
    }
}
