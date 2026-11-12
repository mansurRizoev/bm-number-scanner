package tj.babilon.plugins.numberscanner;

import android.Manifest;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.Toast;
import androidx.activity.OnBackPressedCallback;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.content.ContextCompat;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import com.google.common.util.concurrent.ListenableFuture;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.text.Text;
import com.google.mlkit.vision.text.TextRecognition;
import com.google.mlkit.vision.text.TextRecognizer;
import com.google.mlkit.vision.text.latin.TextRecognizerOptions;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.regex.PatternSyntaxException;

public class ScannerActivity extends AppCompatActivity {

    public static final String EXTRA_PATTERN = "pattern";
    public static final String EXTRA_HINT = "hint";
    public static final String EXTRA_GALLERY = "gallery";
    public static final String EXTRA_VALUE = "value";

    private final AtomicBoolean done = new AtomicBoolean(false);
    private ExecutorService executor;
    private TextRecognizer recognizer;
    private Pattern pattern;
    private PreviewView previewView;

    private final ActivityResultLauncher<String> permissionLauncher = registerForActivityResult(
        new ActivityResultContracts.RequestPermission(),
        granted -> {
            if (granted) startCamera();
            else cancel();
        }
    );

    private final ActivityResultLauncher<String> galleryLauncher = registerForActivityResult(
        new ActivityResultContracts.GetContent(),
        this::recognizeFromGallery
    );

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        setContentView(R.layout.bm_scanner_activity);

        Intent in = getIntent();
        try {
            pattern = Pattern.compile(in.getStringExtra(EXTRA_PATTERN));
        } catch (PatternSyntaxException | NullPointerException e) {
            pattern = Pattern.compile("\\d{6,}");
        }
        ((TextView) findViewById(R.id.bmHint)).setText(in.getStringExtra(EXTRA_HINT));
        ((TextView) findViewById(R.id.bmGallery)).setText(in.getStringExtra(EXTRA_GALLERY));

        View back = findViewById(R.id.bmBack);
        ViewCompat.setOnApplyWindowInsetsListener(back, (v, insets) -> {
            int top = insets.getInsets(WindowInsetsCompat.Type.statusBars()).top;
            ((FrameLayout.LayoutParams) v.getLayoutParams()).topMargin = top + dp(12);
            v.requestLayout();
            return insets;
        });
        back.setOnClickListener(v -> cancel());
        findViewById(R.id.bmGallery).setOnClickListener(v -> galleryLauncher.launch("image/*"));

        getOnBackPressedDispatcher().addCallback(
            this,
            new OnBackPressedCallback(true) {
                @Override
                public void handleOnBackPressed() {
                    cancel();
                }
            }
        );

        previewView = findViewById(R.id.bmPreview);
        executor = Executors.newSingleThreadExecutor();
        recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS);
        permissionLauncher.launch(Manifest.permission.CAMERA);
    }

    private int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }

    @androidx.camera.core.ExperimentalGetImage
    private void startCamera() {
        ListenableFuture<ProcessCameraProvider> future = ProcessCameraProvider.getInstance(this);
        future.addListener(
            () -> {
                try {
                    ProcessCameraProvider provider = future.get();
                    Preview preview = new Preview.Builder().build();
                    preview.setSurfaceProvider(previewView.getSurfaceProvider());

                    ImageAnalysis analysis = new ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build();
                    analysis.setAnalyzer(executor, proxy -> {
                        if (done.get() || proxy.getImage() == null) {
                            proxy.close();
                            return;
                        }
                        InputImage image = InputImage.fromMediaImage(
                            proxy.getImage(),
                            proxy.getImageInfo().getRotationDegrees()
                        );
                        recognizer
                            .process(image)
                            .addOnSuccessListener(text -> {
                                String v = findNumber(text);
                                if (v != null) finishWith(v);
                            })
                            .addOnCompleteListener(t -> proxy.close());
                    });

                    provider.unbindAll();
                    provider.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis);
                } catch (Exception e) {
                    cancel();
                }
            },
            ContextCompat.getMainExecutor(this)
        );
    }

    private void recognizeFromGallery(Uri uri) {
        if (uri == null) return;
        try {
            recognizer
                .process(InputImage.fromFilePath(this, uri))
                .addOnSuccessListener(text -> {
                    String v = findNumber(text);
                    if (v != null) finishWith(v);
                    else Toast.makeText(this, "Номер не найден", Toast.LENGTH_SHORT).show();
                })
                .addOnFailureListener(e ->
                    Toast.makeText(this, "Не удалось прочитать изображение", Toast.LENGTH_SHORT).show()
                );
        } catch (Exception e) {
            Toast.makeText(this, "Не удалось открыть изображение", Toast.LENGTH_SHORT).show();
        }
    }

    private String findNumber(Text text) {
        for (Text.TextBlock block : text.getTextBlocks()) {
            for (Text.Line line : block.getLines()) {
                String cleaned = line.getText().replaceAll("[\\s-]", "");
                Matcher m = pattern.matcher(cleaned);
                if (m.find()) return m.group();
            }
        }
        return null;
    }

    private void finishWith(String value) {
        if (!done.compareAndSet(false, true)) return;
        setResult(RESULT_OK, new Intent().putExtra(EXTRA_VALUE, value));
        finish();
    }

    private void cancel() {
        if (!done.compareAndSet(false, true)) return;
        setResult(RESULT_CANCELED);
        finish();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (recognizer != null) recognizer.close();
        if (executor != null) executor.shutdown();
    }
}
