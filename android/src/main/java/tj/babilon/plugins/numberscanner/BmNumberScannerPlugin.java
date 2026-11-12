package tj.babilon.plugins.numberscanner;

import android.app.Activity;
import android.content.Intent;
import androidx.activity.result.ActivityResult;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.ActivityCallback;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "BmNumberScanner")
public class BmNumberScannerPlugin extends Plugin {

    @PluginMethod
    public void scan(PluginCall call) {
        Intent intent = new Intent(getContext(), ScannerActivity.class);
        intent.putExtra(ScannerActivity.EXTRA_PATTERN, call.getString("pattern", "\\d{6,}"));
        intent.putExtra(ScannerActivity.EXTRA_HINT, call.getString("hint", "Наведите камеру на номер"));
        intent.putExtra(ScannerActivity.EXTRA_GALLERY, call.getString("galleryTitle", "Загрузить из галереи"));
        startActivityForResult(call, intent, "onScanResult");
    }

    @ActivityCallback
    private void onScanResult(PluginCall call, ActivityResult result) {
        if (call == null) return;
        if (result.getResultCode() == Activity.RESULT_OK && result.getData() != null) {
            JSObject ret = new JSObject();
            ret.put("value", result.getData().getStringExtra(ScannerActivity.EXTRA_VALUE));
            call.resolve(ret);
        } else {
            call.reject("cancelled");
        }
    }
}
