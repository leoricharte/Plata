// Evita la ventana de consola en Windows en la versión final.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    tauri::Builder::default()
        // Abre los enlaces externos (target=_blank, http/https) en el navegador del sistema.
        .plugin(tauri_plugin_opener::init())
        .run(tauri::generate_context!())
        .expect("error al iniciar Plata");
}
