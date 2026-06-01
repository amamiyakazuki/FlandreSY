package com.kazuki.zhulihotwater.ui

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import com.kazuki.zhulihotwater.R
import com.kazuki.zhulihotwater.LogActivity
import com.kazuki.zhulihotwater.QrScannerActivity
import com.kazuki.zhulihotwater.runtime.HomeTaskTarget
import com.kazuki.zhulihotwater.runtime.HomeTaskUi
import com.kazuki.zhulihotwater.runtime.LocalDeviceShortcut
import com.kazuki.zhulihotwater.runtime.LocalDeviceType
import com.kazuki.zhulihotwater.runtime.PreviewShuiRuntimeProvider
import com.kazuki.zhulihotwater.runtime.RuntimeActionStatus
import com.kazuki.zhulihotwater.runtime.RuntimeTaskState
import com.kazuki.zhulihotwater.runtime.ScanRouting
import com.kazuki.zhulihotwater.runtime.ShuiRuntimeActions
import com.kazuki.zhulihotwater.runtime.ShuiRuntimeProvider
import com.kazuki.zhulihotwater.runtime.ShuiRuntimeState
import com.kazuki.zhulihotwater.runtime.WasherProgramUi
import com.kazuki.zhulihotwater.runtime.classifyScanRouting
import com.kazuki.zhulihotwater.runtime.homeTasks
import org.json.JSONArray
import org.json.JSONObject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

private sealed class ShuiRoute {
    data class Tab(val tab: MainTab) : ShuiRoute()
    data object WasherOrder : ShuiRoute()
    data object OrderDetail : ShuiRoute()
    data object EmptyDevices : ShuiRoute()
    data object HotwaterDetail : ShuiRoute()
    data class AccountDetail(val kind: AccountKind) : ShuiRoute()
    data object MoreOptions : ShuiRoute()
    data class DrinkingWater(val cd: String) : ShuiRoute()
}

private enum class OrderCategory {
    Hotwater,
    Drinking,
    Washer
}

private enum class AccountKind {
    Zhuli,
    Ujing
}

private data class VersionCheckResult(
    val currentVersion: String,
    val latestVersion: String = "",
    val releaseUrl: String = "",
    val downloadUrl: String = "",
    val notes: String = "",
    val updateAvailable: Boolean = false,
    val error: String? = null
)

@Composable
fun ShuiApp(runtime: ShuiRuntimeProvider = PreviewShuiRuntimeProvider) {
    var route by remember { mutableStateOf<ShuiRoute>(ShuiRoute.Tab(MainTab.Home)) }
    var showAddWasher by remember { mutableStateOf(false) }
    var showPresetWasherPicker by remember { mutableStateOf(false) }
    var selectedMenuDevice by remember { mutableStateOf<LocalDeviceShortcut?>(null) }
    var editingDevice by remember { mutableStateOf<LocalDeviceShortcut?>(null) }
    var scannerMessage by remember { mutableStateOf<String?>(null) }
    var openingVisible by remember { mutableStateOf(true) }
    val runtimeState = runtime.state
    val context = LocalContext.current
    val permissionPrefs = remember(context) { context.getSharedPreferences("shui_permissions", Context.MODE_PRIVATE) }
    var showPermissionIntro by remember {
        mutableStateOf(!permissionPrefs.getBoolean("first_launch_permissions_requested", false))
    }
    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        permissionPrefs.edit().putBoolean("first_launch_permissions_requested", true).apply()
        showPermissionIntro = false
    }
    val requestAllRuntimePermissions = {
        val missing = shuiRuntimePermissions()
            .filter { permission -> ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED }
            .toTypedArray()
        permissionPrefs.edit().putBoolean("first_launch_permissions_requested", true).apply()
        showPermissionIntro = false
        if (missing.isNotEmpty()) {
            permissionLauncher.launch(missing)
        }
    }
    LaunchedEffect(Unit) {
        delay(ShuiMotion.Opening.toLong())
        openingVisible = false
    }
    val scannerLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val qr = result.data?.getStringExtra(QrScannerActivity.EXTRA_QR_RESULT).orEmpty()
            if (qr.isNotBlank()) {
                when (val scan = classifyScanRouting(qr)) {
                    ScanRouting.Washer -> {
                        runtime.actions.scanWasher(qr)
                        showAddWasher = false
                        route = ShuiRoute.WasherOrder
                    }
                    is ScanRouting.DrinkingWater -> {
                        runtime.actions.scanDrinkingWaterAndCreateOrder(scan.cd)
                        showAddWasher = false
                        route = ShuiRoute.Tab(MainTab.Home)
                    }
                    is ScanRouting.Unknown -> {
                        scannerMessage = scan.reason
                    }
                }
            }
        } else {
            scannerMessage = result.data?.getStringExtra(QrScannerActivity.EXTRA_ERROR) ?: "扫码已取消"
        }
    }
    val launchWasherScanner = {
        scannerMessage = null
        scannerLauncher.launch(Intent(context, QrScannerActivity::class.java))
    }

    val selectedTab = when (route) {
        ShuiRoute.WasherOrder -> MainTab.Devices
        ShuiRoute.OrderDetail -> MainTab.Orders
        ShuiRoute.EmptyDevices -> MainTab.Devices
        ShuiRoute.HotwaterDetail -> MainTab.Home
        is ShuiRoute.AccountDetail -> MainTab.Profile
        ShuiRoute.MoreOptions -> MainTab.Profile
        is ShuiRoute.DrinkingWater -> MainTab.Devices
        is ShuiRoute.Tab -> (route as ShuiRoute.Tab).tab
    }

    BackHandler(enabled = showPermissionIntro || showPresetWasherPicker || showAddWasher || selectedMenuDevice != null || editingDevice != null || route !is ShuiRoute.Tab) {
        when {
            showPermissionIntro -> requestAllRuntimePermissions()
            showPresetWasherPicker -> showPresetWasherPicker = false
            editingDevice != null -> editingDevice = null
            selectedMenuDevice != null -> selectedMenuDevice = null
            showAddWasher -> showAddWasher = false
            route !is ShuiRoute.Tab -> route = backRouteFor(route)
        }
    }

    AdaptivePhoneContainer {
        Box(Modifier.fillMaxSize()) {
            AnimatedContent(
                targetState = route,
                transitionSpec = { shuiPageTransform(this) },
                label = "shuiRouteMotion"
            ) { targetRoute ->
                when (targetRoute) {
                    is ShuiRoute.Tab -> when (targetRoute.tab) {
                        MainTab.Home -> HomeScreen(
                            selectedTab = selectedTab,
                            runtimeState = runtimeState,
                            runtimeActions = runtime.actions,
                            onTabSelected = { route = ShuiRoute.Tab(it) },
                            onOpenWasherOrder = launchWasherScanner,
                            onOpenHotwaterDetail = { route = ShuiRoute.HotwaterDetail },
                            onOpenWasherDetail = { route = ShuiRoute.OrderDetail },
                            onOpenDrinkingDetail = { route = ShuiRoute.DrinkingWater(runtimeState.currentWaterReady?.cd.orEmpty()) },
                            onOpenDevices = { route = ShuiRoute.Tab(MainTab.Devices) },
                            onOpenProfile = { route = ShuiRoute.Tab(MainTab.Profile) }
                        )

                        MainTab.Orders -> OrdersScreen(
                            selectedTab = selectedTab,
                            runtimeState = runtimeState,
                            runtimeActions = runtime.actions,
                            onTabSelected = { route = ShuiRoute.Tab(it) },
                            onOpenDetail = { route = ShuiRoute.OrderDetail },
                            onOpenDrinking = { route = ShuiRoute.DrinkingWater(runtimeState.currentWaterReady?.cd.orEmpty()) }
                        )

                        MainTab.Devices -> DevicesScreen(
                            selectedTab = selectedTab,
                            runtimeState = runtimeState,
                            runtimeActions = runtime.actions,
                            onTabSelected = { route = ShuiRoute.Tab(it) },
                            onOpenOrder = { route = ShuiRoute.WasherOrder },
                            onAdd = { showAddWasher = true },
                            onMenu = { selectedMenuDevice = it },
                            onOpenDrinking = { device ->
                                val qrOrCd = device.qrUrl ?: device.cd.orEmpty()
                                route = ShuiRoute.DrinkingWater(qrOrCd)
                            },
                            onOpenEmpty = { route = ShuiRoute.EmptyDevices }
                        )

                        MainTab.Profile -> ProfileScreen(
                            selectedTab = selectedTab,
                            runtimeState = runtimeState,
                            onTabSelected = { route = ShuiRoute.Tab(it) },
                            onOpenZhuliAccount = { route = ShuiRoute.AccountDetail(AccountKind.Zhuli) },
                            onOpenUjingAccount = { route = ShuiRoute.AccountDetail(AccountKind.Ujing) },
                            onOpenMoreOptions = { route = ShuiRoute.MoreOptions }
                        )
                    }

                    ShuiRoute.WasherOrder -> WasherOrderScreen(
                        runtimeState = runtimeState,
                        runtimeActions = runtime.actions,
                        onBack = { route = ShuiRoute.Tab(MainTab.Devices) }
                    )
                    ShuiRoute.OrderDetail -> OrderDetailScreen(
                        selectedTab = selectedTab,
                        runtimeState = runtimeState,
                        runtimeActions = runtime.actions,
                        onBack = { route = ShuiRoute.Tab(MainTab.Orders) },
                        onTabSelected = { route = ShuiRoute.Tab(it) }
                    )

                    ShuiRoute.EmptyDevices -> EmptyDevicesScreen(
                        selectedTab = selectedTab,
                        onBack = { route = ShuiRoute.Tab(MainTab.Devices) },
                        onAdd = { showAddWasher = true },
                        onTabSelected = { route = ShuiRoute.Tab(it) }
                    )
                    ShuiRoute.HotwaterDetail -> HotwaterDetailScreen(
                        selectedTab = selectedTab,
                        runtimeState = runtimeState,
                        runtimeActions = runtime.actions,
                        onBack = { route = ShuiRoute.Tab(MainTab.Home) },
                        onTabSelected = { route = ShuiRoute.Tab(it) }
                    )
                    is ShuiRoute.AccountDetail -> AccountDetailScreen(
                        selectedTab = selectedTab,
                        kind = targetRoute.kind,
                        runtimeState = runtimeState,
                        runtimeActions = runtime.actions,
                        onBack = { route = ShuiRoute.Tab(MainTab.Profile) },
                        onTabSelected = { route = ShuiRoute.Tab(it) }
                    )
                    ShuiRoute.MoreOptions -> MoreOptionsScreen(
                        selectedTab = selectedTab,
                        runtimeActions = runtime.actions,
                        onBack = { route = ShuiRoute.Tab(MainTab.Profile) },
                        onTabSelected = { route = ShuiRoute.Tab(it) }
                    )
                    is ShuiRoute.DrinkingWater -> DrinkingWaterScreen(
                        selectedTab = selectedTab,
                        cd = targetRoute.cd,
                        runtimeState = runtimeState,
                        runtimeActions = runtime.actions,
                        onBack = { route = ShuiRoute.Tab(MainTab.Devices) },
                        onCompleted = { route = ShuiRoute.Tab(MainTab.Home) },
                        onTabSelected = { route = ShuiRoute.Tab(it) }
                    )
                }
            }
            AnimatedVisibility(visible = showAddWasher, enter = shuiDialogEnter(), exit = shuiDialogExit()) {
                AddWasherDialog(
                    onDismiss = { showAddWasher = false },
                    onScan = launchWasherScanner,
                    onPreset = { showPresetWasherPicker = true }
                )
            }
            AnimatedVisibility(visible = showPresetWasherPicker, enter = shuiDialogEnter(), exit = shuiDialogExit()) {
                PresetWasherDeviceDialog(
                    onDismiss = { showPresetWasherPicker = false },
                    onSelect = { device ->
                        runtime.actions.addPresetWasherDevice(device.name, device.qrCode)
                        scannerMessage = "已添加 ${device.name}"
                        showPresetWasherPicker = false
                        showAddWasher = false
                    }
                )
            }
            AnimatedVisibility(visible = selectedMenuDevice != null, enter = shuiDialogEnter(), exit = shuiDialogExit()) {
                val device = selectedMenuDevice ?: return@AnimatedVisibility
                DeviceActionPopup(
                    onDismiss = { selectedMenuDevice = null },
                    onEdit = {
                        editingDevice = device
                        selectedMenuDevice = null
                    },
                    onDelete = {
                        runtime.actions.deleteLocalDevice(device.id)
                        selectedMenuDevice = null
                    }
                )
            }
            AnimatedVisibility(visible = editingDevice != null, enter = shuiDialogEnter(), exit = shuiDialogExit()) {
                val device = editingDevice ?: return@AnimatedVisibility
                EditDeviceNameDialog(
                    device = device,
                    onDismiss = { editingDevice = null },
                    onSave = { name ->
                        runtime.actions.renameLocalDevice(device.id, name)
                        editingDevice = null
                    }
                )
            }
            AnimatedVisibility(visible = scannerMessage != null, enter = shuiStatusEnter(), exit = shuiStatusExit()) {
                val message = scannerMessage ?: return@AnimatedVisibility
                ScannerMessageBanner(
                    message = message,
                    onDismiss = { scannerMessage = null },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(horizontal = 12.dp, vertical = 78.dp)
                )
            }
            AnimatedVisibility(
                visible = openingVisible,
                enter = fadeIn(tween(ShuiMotion.Quick)),
                exit = fadeOut(tween(ShuiMotion.Normal, easing = ShuiMotion.EaseOut))
            ) {
                OpeningMotionOverlay()
            }
            AnimatedVisibility(visible = showPermissionIntro, enter = shuiDialogEnter(), exit = shuiDialogExit()) {
                FirstLaunchPermissionDialog(onConfirm = requestAllRuntimePermissions)
            }
        }
    }
}

private fun backRouteFor(route: ShuiRoute): ShuiRoute.Tab {
    return when (route) {
        ShuiRoute.WasherOrder -> ShuiRoute.Tab(MainTab.Devices)
        ShuiRoute.OrderDetail -> ShuiRoute.Tab(MainTab.Orders)
        ShuiRoute.EmptyDevices -> ShuiRoute.Tab(MainTab.Devices)
        ShuiRoute.HotwaterDetail -> ShuiRoute.Tab(MainTab.Home)
        is ShuiRoute.AccountDetail -> ShuiRoute.Tab(MainTab.Profile)
        ShuiRoute.MoreOptions -> ShuiRoute.Tab(MainTab.Profile)
        is ShuiRoute.DrinkingWater -> ShuiRoute.Tab(MainTab.Devices)
        is ShuiRoute.Tab -> route
    }
}

private data class PresetWasherDevice(val name: String, val qrCode: String)

private val haiqiPresetWashers = listOf(
    PresetWasherDevice("海七-二楼左", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007107"),
    PresetWasherDevice("海七-二楼中", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007129"),
    PresetWasherDevice("海七-二楼右", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007119"),
    PresetWasherDevice("海七-三楼左", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007230"),
    PresetWasherDevice("海七-三楼中", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007196"),
    PresetWasherDevice("海七-三楼右", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A0007604202108140003053"),
    PresetWasherDevice("海七-四楼左", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A0007604202108140002704"),
    PresetWasherDevice("海七-四楼中", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007239"),
    PresetWasherDevice("海七-四楼右", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A0007604202108140002884"),
    PresetWasherDevice("海七-五楼左", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A0007604202108140003091"),
    PresetWasherDevice("海七-五楼中", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A0007604202108140003074"),
    PresetWasherDevice("海七-五楼右", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007226"),
    PresetWasherDevice("海七-六楼左", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007220"),
    PresetWasherDevice("海七-六楼中", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007382"),
    PresetWasherDevice("海七-六楼右", "http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007189")
)

private fun shuiRuntimePermissions(): List<String> {
    return buildList {
        add(Manifest.permission.CAMERA)
        add(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            add(Manifest.permission.BLUETOOTH_SCAN)
            add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            add(Manifest.permission.POST_NOTIFICATIONS)
        }
    }
}

@Composable
private fun FirstLaunchPermissionDialog(onConfirm: () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = .46f)),
        contentAlignment = Alignment.Center
    ) {
        SectionCard(
            modifier = Modifier.padding(horizontal = 28.dp),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp)
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                DecorativeImage(R.drawable.sleep, Modifier.size(108.dp))
                Spacer(Modifier.height(8.dp))
                Text("先给小助手一点权限吧", color = ShuiColors.DeepText, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                Text(
                    text = "扫码、热水蓝牙、状态通知都需要系统权限。点一下我就会一次性申请，之后就不用反复打扰你啦。",
                    color = ShuiColors.MutedText,
                    fontSize = 14.sp,
                    lineHeight = 21.sp,
                    textAlign = TextAlign.Center
                )
                Spacer(Modifier.height(16.dp))
                PrimaryGradientButton("好，开启权限", Modifier.fillMaxWidth(), onClick = onConfirm)
            }
        }
    }
}

@Composable
private fun PresetWasherDeviceDialog(
    onDismiss: () -> Unit,
    onSelect: (PresetWasherDevice) -> Unit
) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = .48f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.Center
    ) {
        SectionCard(
            modifier = Modifier
                .padding(horizontal = 18.dp)
                .clickable(enabled = false) {},
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp)
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Spacer(Modifier.weight(1f))
                    Text("选择海七已有设备", color = ShuiColors.DeepText, fontSize = 19.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.weight(1f))
                    Text("×", color = ShuiColors.PrimaryLight, fontSize = 22.sp, modifier = Modifier.clickable(onClick = onDismiss))
                }
                Spacer(Modifier.height(12.dp))
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(360.dp)
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    haiqiPresetWashers.chunked(3).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                            row.forEach { device ->
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(58.dp)
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(Color.White.copy(alpha = .82f))
                                        .border(1.dp, ShuiColors.CardBorder, RoundedCornerShape(12.dp))
                                        .shuiPressable(onClick = { onSelect(device) }),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        device.name,
                                        color = ShuiColors.DeepText,
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Bold,
                                        textAlign = TextAlign.Center,
                                        maxLines = 2,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            }
                        }
                    }
                }
                Spacer(Modifier.height(10.dp))
                Text("只保存到本地列表，不会绑定到官方账号", color = ShuiColors.MutedText, fontSize = 12.sp)
            }
        }
    }
}

@Composable
private fun ScannerMessageBanner(message: String, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    SectionCard(
        modifier = modifier.shuiPressable(onClick = onDismiss),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 10.dp)
    ) {
        Text(
            text = message,
            color = ShuiColors.Orange,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun OpeningMotionOverlay() {
    var started by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { started = true }
    val markScale by animateFloatAsState(
        targetValue = if (started) 1f else 0f,
        animationSpec = tween(ShuiMotion.Opening, easing = ShuiMotion.EaseOut),
        label = "openingMarkScale"
    )
    Box(
        Modifier
            .fillMaxSize()
            .background(ShuiColors.Background),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            DecorativeImage(
                R.drawable.home_top_character,
                modifier = Modifier
                    .size(116.dp)
                    .scale(0.92f + markScale * 0.08f)
            )
            Text("芙兰水衣", color = ShuiColors.Primary, fontSize = 30.sp, fontWeight = FontWeight.Bold)
            Text("水、衣、热水，轻轻开始", color = ShuiColors.MutedText, fontSize = 13.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun PrimaryPageScaffold(
    title: String,
    selectedTab: MainTab,
    onTabSelected: (MainTab) -> Unit,
    modifier: Modifier = Modifier,
    showBack: Boolean = false,
    showSettings: Boolean = false,
    showAdd: Boolean = false,
    onBack: () -> Unit = {},
    onSettings: () -> Unit = {},
    onAdd: () -> Unit = {},
    headerHeight: androidx.compose.ui.unit.Dp = 116.dp,
    character: @Composable (BoxScope.() -> Unit)? = null,
    bottomCharacter: Boolean = false,
    content: @Composable () -> Unit
) {
    val density = LocalDensity.current
    val navBottom = with(density) { WindowInsets.navigationBars.getBottom(this).toDp() }
    Box(modifier.fillMaxSize().background(ShuiColors.Background)) {
        Column(Modifier.fillMaxSize()) {
            TopHeader(
                title = title,
                showBack = showBack,
                showSettings = showSettings,
                showAdd = showAdd,
                onBack = onBack,
                onSettings = onSettings,
                onAdd = onAdd,
                character = character,
                height = headerHeight
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 12.dp)
                    .padding(bottom = (if (bottomCharacter) 124.dp else 68.dp) + navBottom)
            ) {
                content()
            }
        }
        if (bottomCharacter) {
            DecorativeImage(
                R.drawable.order_bottom_character,
                Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 48.dp + navBottom)
                    .offset(x = 14.dp, y = 6.dp)
                    .size(132.dp)
            )
        }
        WavyBottomBar(
            selectedTab = selectedTab,
            onTabSelected = onTabSelected,
            modifier = Modifier.align(Alignment.BottomCenter)
        )
    }
}

@Composable
private fun HomeScreen(
    selectedTab: MainTab,
    runtimeState: ShuiRuntimeState,
    runtimeActions: ShuiRuntimeActions,
    onTabSelected: (MainTab) -> Unit,
    onOpenWasherOrder: () -> Unit,
    onOpenHotwaterDetail: () -> Unit,
    onOpenWasherDetail: () -> Unit,
    onOpenDrinkingDetail: () -> Unit,
    onOpenDevices: () -> Unit,
    onOpenProfile: () -> Unit
) {
    PrimaryPageScaffold(
        title = "芙兰水衣",
        selectedTab = selectedTab,
        onTabSelected = onTabSelected,
        showSettings = true,
        onSettings = onOpenProfile,
        headerHeight = 108.dp,
        character = {
            DecorativeImage(
                R.drawable.home_top_character,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(start = 24.dp)
                    .offset(y = 6.dp)
                    .size(96.dp)
            )
        }
    ) {
        Column(Modifier.padding(top = 6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            OngoingCard(runtimeState.homeTasks, onOpenHotwaterDetail, onOpenWasherDetail, onOpenDrinkingDetail)
            homeWaterMessage(runtimeState)?.let { (state, message) ->
                RuntimeStatusBanner(message, state)
            }
            HotWaterCard(runtimeState.hotwaterStart, runtimeState.hotwaterStop, runtimeActions)
            ScanCard(onClick = onOpenWasherOrder)
            WasherDeviceSummaryCard(runtimeState.localDevices, onOpenDevices)
        }
    }
}

private fun homeWaterMessage(runtimeState: ShuiRuntimeState): Pair<RuntimeTaskState, String>? {
    return when {
        runtimeState.waterScan.state == RuntimeTaskState.Failure ->
            runtimeState.waterScan.state to (runtimeState.waterScan.message ?: "饮水扫码失败")
        runtimeState.waterOrder.state == RuntimeTaskState.Failure ->
            runtimeState.waterOrder.state to (runtimeState.waterOrder.message ?: "接水订单创建失败")
        runtimeState.waterOrder.state == RuntimeTaskState.Loading ->
            runtimeState.waterOrder.state to (runtimeState.waterOrder.message ?: "正在创建接水订单")
        runtimeState.waterOrder.state == RuntimeTaskState.Success && runtimeState.waterOrder.message != null ->
            runtimeState.waterOrder.state to runtimeState.waterOrder.message
        else -> null
    }
}

@Composable
private fun OngoingCard(
    tasks: List<HomeTaskUi>,
    onOpenHotwaterDetail: () -> Unit,
    onOpenWasherDetail: () -> Unit,
    onOpenDrinkingDetail: () -> Unit
) {
    SectionCard {
        Column {
            HomeSectionTitle(R.drawable.shui_fire, "进行中")
            Spacer(Modifier.height(6.dp))
            AnimatedContent(
                targetState = tasks,
                transitionSpec = { shuiPageTransform(this) },
                label = "ongoingTasksMotion"
            ) { animatedTasks ->
                if (animatedTasks.isEmpty()) {
                    RunningStatusEmpty()
                } else {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        animatedTasks.take(3).forEach { task ->
                            RunningStatusCard(
                                task = task,
                                modifier = Modifier.weight(1f),
                                onClick = when (task.target) {
                                    HomeTaskTarget.HotwaterDetail -> onOpenHotwaterDetail
                                    HomeTaskTarget.WasherOrderDetail -> onOpenWasherDetail
                                    HomeTaskTarget.DrinkingWaterDetail -> onOpenDrinkingDetail
                                }
                            )
                        }
                        repeat((3 - animatedTasks.size.coerceAtMost(3)).coerceAtLeast(0)) {
                            Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun OngoingCard() {
    SectionCard {
        Column {
            HomeSectionTitle(R.drawable.shui_fire, "进行中")
            Spacer(Modifier.height(6.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                RunningStatusCard(R.drawable.shui_reshui, "热水使用中", "剩余 02:35", ShuiColors.Primary, Modifier.weight(1f))
                RunningStatusCard(R.drawable.shui_jieshui, "接水中", "订单号 1234", ShuiColors.Blue, Modifier.weight(1f))
                RunningStatusCard(R.drawable.shui_yifu, "洗衣待支付", "¥2.50", ShuiColors.Orange, Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun HomeSectionTitle(iconRes: Int, title: String, useThreeStars: Boolean = true) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        DecorativeImage(iconRes, Modifier.size(28.dp))
        Spacer(Modifier.width(8.dp))
        Text(title, color = ShuiColors.DeepText, fontSize = 19.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.width(8.dp))
        DecorativeImage(
            if (useThreeStars) R.drawable.shui_3star else R.drawable.shui_star,
            Modifier.size(if (useThreeStars) 42.dp else 20.dp)
        )
        Spacer(Modifier.weight(1f))
        Box(Modifier.width(78.dp).height(1.dp).background(ShuiColors.CardBorder.copy(alpha = .58f)))
        Spacer(Modifier.width(8.dp))
        DecorativeImage(R.drawable.shui_cloud, Modifier.size(26.dp))
        Spacer(Modifier.width(8.dp))
        Box(Modifier.width(78.dp).height(1.dp).background(ShuiColors.CardBorder.copy(alpha = .58f)))
    }
}

@Composable
private fun RunningStatusEmpty() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(58.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(ShuiColors.Primary.copy(alpha = .04f))
            .border(1.dp, ShuiColors.CardBorder.copy(alpha = .65f), RoundedCornerShape(12.dp)),
        contentAlignment = Alignment.Center
    ) {
        Text("无任务", color = ShuiColors.MutedText, fontSize = 14.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun RunningStatusCard(task: HomeTaskUi, modifier: Modifier, onClick: () -> Unit) {
    val iconRes = when (task.iconName) {
        "reshui" -> R.drawable.shui_reshui
        "jieshui" -> R.drawable.shui_jieshui
        "yifu" -> R.drawable.shui_yifu
        else -> R.drawable.shui_3star
    }
    Column(
        modifier = modifier
            .height(66.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(taskColor(task).copy(alpha = .05f))
            .border(1.dp, taskColor(task).copy(alpha = .58f), RoundedCornerShape(12.dp))
            .shuiPressable(scale = ShuiMotion.SoftPressedScale, onClick = onClick)
            .padding(horizontal = 5.dp, vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        DecorativeImage(iconRes, Modifier.size(28.dp))
        Text(task.title, color = taskColor(task), fontSize = 11.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(task.extra, color = ShuiColors.Brown, fontSize = 10.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

private fun taskColor(task: HomeTaskUi): Color {
    return when (task.target) {
        HomeTaskTarget.HotwaterDetail -> ShuiColors.Primary
        HomeTaskTarget.WasherOrderDetail -> ShuiColors.Blue
        HomeTaskTarget.DrinkingWaterDetail -> ShuiColors.Blue
    }
}

@Composable
private fun RunningStatusCard(iconRes: Int, title: String, sub: String, color: Color, modifier: Modifier) {
    Column(
        modifier = modifier
            .height(66.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(color.copy(alpha = .04f))
            .border(1.dp, color.copy(alpha = .65f), RoundedCornerShape(12.dp))
            .padding(horizontal = 6.dp, vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        DecorativeImage(iconRes, Modifier.size(30.dp))
        Text(title, color = color, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(sub, color = ShuiColors.DeepText, fontSize = 10.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun HotWaterCard(
    startStatus: RuntimeActionStatus,
    stopStatus: RuntimeActionStatus,
    actions: ShuiRuntimeActions
) {
    val isStarting = startStatus.state == RuntimeTaskState.Loading
    val isStopping = stopStatus.state == RuntimeTaskState.Loading
    val visibleStatus = when {
        isStopping -> stopStatus
        stopStatus.state == RuntimeTaskState.Success -> stopStatus
        stopStatus.state == RuntimeTaskState.Failure -> stopStatus
        stopStatus.state == RuntimeTaskState.Unavailable -> stopStatus
        stopStatus.state == RuntimeTaskState.PermissionRequired -> stopStatus
        else -> startStatus
    }
    val showingStopStatus = visibleStatus == stopStatus && stopStatus.state != RuntimeTaskState.Idle
    val statusText = when (visibleStatus.state) {
        RuntimeTaskState.Loading -> if (showingStopStatus) "正在关闭热水" else "正在启动热水"
        RuntimeTaskState.Success -> if (showingStopStatus) "热水已关闭" else "热水已启动"
        RuntimeTaskState.LoginRequired -> "需要住理登录"
        RuntimeTaskState.PermissionRequired -> "需要授权"
        RuntimeTaskState.Failure -> if (showingStopStatus) "关闭失败" else "启动失败"
        RuntimeTaskState.Unavailable -> "暂不可操作"
        else -> "热水待启动"
    }
    val statusColor = when (visibleStatus.state) {
        RuntimeTaskState.Success -> ShuiColors.Green
        RuntimeTaskState.Failure, RuntimeTaskState.LoginRequired, RuntimeTaskState.PermissionRequired, RuntimeTaskState.Unavailable -> ShuiColors.Orange
        else -> ShuiColors.Primary
    }

    SectionCard {
        Column {
            HomeSectionTitle(R.drawable.shui_fire, "热水控制", useThreeStars = false)
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    CurrentStatusLabel()
                    Spacer(Modifier.height(6.dp))
                    Text("≋  $statusText", color = statusColor, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        PrimaryGradientButton(
                            if (isStarting) "启动中" else "开热水",
                            Modifier.weight(1f),
                            enabled = !isStarting && !isStopping,
                            onClick = { actions.startHotwater() }
                        )
                        PrimaryGradientButton(
                            if (isStopping) "关闭中" else "关热水",
                            Modifier.weight(1f),
                            enabled = !isStarting && !isStopping,
                            onClick = { actions.stopHotwater() }
                        )
                    }
                }
                ShadowedImage(R.drawable.hot_water_character, Modifier.size(108.dp))
            }
            Spacer(Modifier.height(10.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(ShuiColors.Primary.copy(alpha = .05f))
                    .dashedBorder(ShuiColors.PrimaryLight, 12.dp)
                    .padding(horizontal = 14.dp, vertical = 7.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("⚠", color = ShuiColors.Primary, fontSize = 19.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.width(10.dp))
                    Text(
                        visibleStatus.message ?: "当前无错误",
                        color = ShuiColors.Primary,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f)
                    )
                    DecorativeImage(R.drawable.shui_bianfu, Modifier.size(48.dp), alpha = .48f)
                }
            }
        }
    }
}

@Composable
private fun CurrentStatusLabel() {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        DashedRule(Modifier.weight(1f))
        Text("当前状态", color = ShuiColors.DeepText, fontSize = 14.sp, modifier = Modifier.padding(horizontal = 12.dp))
        DashedRule(Modifier.weight(1f))
    }
}

@Composable
private fun DashedRule(modifier: Modifier = Modifier) {
    Canvas(modifier.height(1.dp)) {
        drawLine(
            color = ShuiColors.CardBorder.copy(alpha = .82f),
            start = Offset.Zero,
            end = Offset(size.width, 0f),
            strokeWidth = 1.4.dp.toPx(),
            cap = StrokeCap.Round,
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 8f))
        )
    }
}

@Composable
private fun ScanCard(onClick: () -> Unit) {
    SectionCard {
        Column {
            HomeSectionTitle(R.drawable.shui_scancode, "扫码使用")
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(104.dp)
                    .padding(top = 6.dp)
                    .shuiPressable(scale = ShuiMotion.SoftPressedScale, onClick = onClick),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    Modifier
                        .matchParentSize()
                        .clip(RoundedCornerShape(14.dp))
                        .background(ShuiColors.WeakPink.copy(alpha = .62f))
                        .border(1.dp, ShuiColors.CardBorder, RoundedCornerShape(14.dp))
                )
                DecorativeImage(R.drawable.scan, Modifier.size(84.dp))
                DecorativeImage(
                    R.drawable.shui_bianfu,
                    Modifier
                        .align(Alignment.CenterStart)
                        .padding(start = 92.dp, top = 8.dp)
                        .size(50.dp),
                    alpha = .35f
                )
                ShadowedImage(
                    R.drawable.scan_character_v2,
                    Modifier
                        .align(Alignment.TopEnd)
                        .offset(x = (-10).dp, y = (-24).dp)
                        .size(104.dp)
                )
                Text("扫描饮水机或洗衣机二维码", color = ShuiColors.DeepText, fontSize = 14.sp, modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 10.dp))
            }
        }
    }
}

@Composable
private fun WasherDeviceSummaryCard(localDevices: List<LocalDeviceShortcut>, onOpenDevices: () -> Unit) {
    val washerDevices = localDevices.filter { it.deviceType == LocalDeviceType.Washer }
    val availableCount = washerDevices.count { it.lastStatus == "可下单" }
    val unknownCount = (washerDevices.size - availableCount).coerceAtLeast(0)
    SectionCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                HomeSectionTitle(R.drawable.shui_yifu, "洗衣设备")
                Spacer(Modifier.height(8.dp))
                Row(
                    Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .border(1.dp, ShuiColors.CardBorder, RoundedCornerShape(12.dp))
                        .padding(horizontal = 10.dp, vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("已添加设备", color = ShuiColors.DeepText, fontSize = 13.sp)
                        Row(verticalAlignment = Alignment.Bottom) {
                            Text("${washerDevices.size}", color = ShuiColors.Primary, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.width(4.dp))
                            Text("台", color = ShuiColors.DeepText, fontSize = 12.sp, modifier = Modifier.padding(bottom = 3.dp))
                        }
                    }
                    Box(Modifier.padding(horizontal = 12.dp).width(1.dp).height(46.dp).background(ShuiColors.CardBorder.copy(alpha = .55f)))
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("可用 / 未知", color = ShuiColors.DeepText, fontSize = 13.sp)
                        Row(verticalAlignment = Alignment.Bottom) {
                        Text("$availableCount", color = ShuiColors.Green, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                            Text(" / ", color = ShuiColors.DeepText, fontSize = 18.sp)
                            Text("$unknownCount", color = ShuiColors.Orange, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                            Text("台", color = ShuiColors.DeepText, fontSize = 12.sp)
                        }
                    }
                }
            }
            Box(
                modifier = Modifier
                    .width(154.dp)
                    .height(108.dp)
                    .shuiPressable(scale = ShuiMotion.SoftPressedScale, onClick = onOpenDevices)
            ) {
                DecorativeImage(
                    R.drawable.washer_character,
                    Modifier
                        .align(Alignment.Center)
                        .size(112.dp)
                )
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(bottom = 4.dp)
                        .width(82.dp)
                        .height(34.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(Brush.linearGradient(listOf(ShuiColors.PrimaryLight, ShuiColors.Primary, ShuiColors.PrimaryDark))),
                    contentAlignment = Alignment.Center
                ) {
                    Text("选择设备  ›", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun ShadowedImage(resId: Int, modifier: Modifier) {
    Box(modifier, contentAlignment = Alignment.Center) {
        Canvas(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(24.dp)
        ) {
            drawOval(
                color = ShuiColors.Primary.copy(alpha = .13f),
                topLeft = Offset(size.width * .18f, size.height * .25f),
                size = androidx.compose.ui.geometry.Size(size.width * .64f, size.height * .45f)
            )
        }
        DecorativeImage(resId, Modifier.fillMaxSize())
    }
}

@Composable
private fun WasherRuntimeInfoCard(program: WasherProgramUi?, localDevices: List<LocalDeviceShortcut>) {
    val matchedDevice = program?.let { current ->
        localDevices.firstOrNull { it.id == current.deviceId }
    }
    val title = matchedDevice?.customName?.takeIf { it.isNotBlank() }
        ?: program?.deviceNo?.takeIf { it.isNotBlank() }
        ?: program?.deviceTypeName?.takeIf { it.isNotBlank() }
        ?: "未选择洗衣机"
    val statusText = when {
        program == null -> "未选择"
        program.createOrderEnabled -> "可下单"
        program.reason.isNotBlank() -> program.reason
        else -> "不可下单"
    }
    val statusColor = when {
        program?.createOrderEnabled == true -> ShuiColors.Green
        program == null -> ShuiColors.Orange
        else -> ShuiColors.Orange
    }
    val deviceNo = program?.deviceNo?.takeIf { it.isNotBlank() }
        ?: matchedDevice?.deviceNo?.takeIf { it.isNotBlank() }
        ?: program?.deviceId?.takeIf { it.isNotBlank() }
        ?: "未选择"
    val storeName = program?.storeName?.takeIf { it.isNotBlank() }
        ?: matchedDevice?.storeName?.takeIf { it.isNotBlank() }
        ?: "选择或扫描设备后显示真实地址"

    SectionCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 14.dp, vertical = 16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            DecorativeImage(R.drawable.washer_machine, Modifier.size(74.dp))
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        title,
                        color = ShuiColors.DeepText,
                        fontSize = 21.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(Modifier.width(8.dp))
                    StatusPill(statusText, statusColor, Modifier.widthIn(max = 96.dp), filled = true)
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    "设备号：$deviceNo",
                    color = ShuiColors.Brown,
                    fontSize = 15.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    "地址：$storeName",
                    color = ShuiColors.Brown,
                    fontSize = 14.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

@Composable
private fun WasherOrderScreen(
    runtimeState: ShuiRuntimeState,
    runtimeActions: ShuiRuntimeActions,
    onBack: () -> Unit
) {
    val program = runtimeState.washerProgram
    var selectedModelId by remember(program?.deviceId) {
        mutableStateOf(program?.defaultWashModelId ?: 0)
    }
    var selectedTemperatureId by remember(program?.deviceId) { mutableStateOf(1) }
    var selectedDetergentGearId by remember(program?.deviceId, selectedModelId) { mutableStateOf<Int?>(null) }
    var selectedDisinfectantGearId by remember(program?.deviceId, selectedModelId) { mutableStateOf<Int?>(null) }
    var autoStartAfterPayment by remember { mutableStateOf(true) }
    val modelOptions = program?.models.orEmpty()
    val selectedModel = modelOptions.firstOrNull { it.id == selectedModelId }
    val detergentOptions = selectedModel?.additionGroups
        ?.firstOrNull { it.key == "wp_detergentGearId" }
        ?.options
        .orEmpty()
    val disinfectantOptions = selectedModel?.additionGroups
        ?.firstOrNull { it.key == "wp_disinfectantGearId" }
        ?.options
        .orEmpty()
    val selectedDetergent = detergentOptions.firstOrNull { it.id == selectedDetergentGearId }
    val selectedDisinfectant = disinfectantOptions.firstOrNull { it.id == selectedDisinfectantGearId }
    val totalPriceFen = (selectedModel?.priceFen ?: 0) +
        (selectedDetergent?.priceFen ?: 0) +
        (selectedDisinfectant?.priceFen ?: 0)
    val orderLoading = runtimeState.washerOrder.state == RuntimeTaskState.Loading

    Column(Modifier.fillMaxSize().background(ShuiColors.Background)) {
        TopHeader(title = "洗衣下单", showBack = true, onBack = onBack, height = 116.dp)
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(top = 8.dp, bottom = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            WasherRuntimeInfoCard(program = program, localDevices = runtimeState.localDevices)
            if (program == null) {
                RuntimeStatusBanner("请先扫描洗衣机二维码，识别设备后再创建订单", RuntimeTaskState.LoginRequired)
            } else {
                RuntimeStatusBanner(
                    "${program.deviceNo.ifBlank { program.deviceId }} · ${program.storeName.ifBlank { "未知门店" }}",
                    runtimeState.washerScan.state
                )
            }
            OptionSection(
                "▱",
                "套餐选择",
                "请选择洗衣套餐",
                modelOptions.take(4).mapIndexed { index, model ->
                    Triple(model.name, formatFenAmount(model.priceFen), washerModelIcon(index))
                }.ifEmpty {
                    listOf(Triple("待扫码", null, "shirt"))
                },
                selected = modelOptions.take(4).indexOfFirst { it.id == selectedModelId }.coerceAtLeast(0),
                onSelected = { index ->
                    modelOptions.getOrNull(index)?.let { selectedModelId = it.id }
                }
            )
            val temperatureOptions = listOf(
                Triple("常温", null, "temp_normal") to 1,
                Triple("30°C", null, "temp_30") to 2,
                Triple("40°C", null, "temp_40") to 3,
                Triple("60°C", null, "temp_60") to 4
            )
            OptionSection(
                "♨",
                "温度选择",
                "请选择洗涤温度",
                temperatureOptions.map { it.first },
                selected = temperatureOptions.indexOfFirst { it.second == selectedTemperatureId }.coerceAtLeast(0),
                compact = true,
                onSelected = { index -> selectedTemperatureId = temperatureOptions[index].second }
            )
            if (detergentOptions.isNotEmpty()) {
                val options = listOf(Triple("不添加", null, "no_bottle")) + detergentOptions.mapIndexed { index, option ->
                    Triple(option.name, formatFenAmount(option.priceFen), if (index == 0) "bottle" else "bottles")
                }
                OptionSection(
                    "▱",
                    "洗衣液选择",
                    "请选择洗衣液用量",
                    options,
                    selected = detergentOptions.indexOfFirst { it.id == selectedDetergentGearId }.let { if (it >= 0) it + 1 else 0 },
                    compact = true,
                    onSelected = { index -> selectedDetergentGearId = if (index == 0) null else detergentOptions.getOrNull(index - 1)?.id }
                )
            }
            if (disinfectantOptions.isNotEmpty()) {
                val options = listOf(Triple("不添加", null, "no_shield")) + disinfectantOptions.mapIndexed { index, option ->
                    Triple(option.name, formatFenAmount(option.priceFen), if (index == 0) "shield" else "shields")
                }
                OptionSection(
                    "▱",
                    "除菌液选择",
                    "请选择除菌液用量",
                    options,
                    selected = disinfectantOptions.indexOfFirst { it.id == selectedDisinfectantGearId }.let { if (it >= 0) it + 1 else 0 },
                    compact = true,
                    onSelected = { index -> selectedDisinfectantGearId = if (index == 0) null else disinfectantOptions.getOrNull(index - 1)?.id }
                )
            }
            AutoStartNoticeCard(
                enabled = autoStartAfterPayment,
                onEnabledChange = { autoStartAfterPayment = it }
            )
            runtimeState.washerOrder.message?.let { message ->
                RuntimeStatusBanner(message, runtimeState.washerOrder.state)
            }
            if (runtimeState.currentWasherOrder != null) {
                CurrentWasherOrderPaymentCard(runtimeState, runtimeActions, autoStartAfterPayment)
            }
            PriceBar(
                amount = formatFenAmount(totalPriceFen),
                enabled = program != null && selectedModelId != 0 && !orderLoading,
                buttonText = if (orderLoading) "创建中" else "创建订单",
                onCreate = { runtimeActions.createWasherOrder(selectedModelId, selectedTemperatureId, selectedDetergentGearId, selectedDisinfectantGearId) },
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun CurrentWasherOrderPaymentCard(
    runtimeState: ShuiRuntimeState,
    runtimeActions: ShuiRuntimeActions,
    autoStartAfterPayment: Boolean = true
) {
    val order = runtimeState.currentWasherOrder ?: return
    val paying = runtimeState.washerPayment.state == RuntimeTaskState.PaymentInProgress
    val orderBusy = runtimeState.washerOrder.state == RuntimeTaskState.Loading
    val canPay = order.status == "10"
    val canStart = order.status == "20"
    val canStop = order.status == "21" || order.status == "40"
    SectionCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("当前订单", color = ShuiColors.DeepText, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.weight(1f))
                StatusPill(order.statusText, ShuiColors.Orange, filled = true)
            }
            DetailRow("订单号", order.orderId)
            DetailRow("设备号", order.deviceNo)
            DetailRow("金额", formatDisplayAmount(order.payPrice))
            if (order.remainTimeSeconds > 0) {
                DetailRow("剩余时间", formatSeconds(order.remainTimeSeconds))
            } else if (order.countDownSeconds > 0) {
                DetailRow("保留时间", formatSeconds(order.countDownSeconds))
            }
            Text("暂时只支持支付宝支付", color = ShuiColors.MutedText, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            runtimeState.washerPayment.message?.let { message ->
                RuntimeStatusBanner(message, runtimeState.washerPayment.state)
            }
            if (canPay) {
                PrimaryGradientButton(
                    if (paying) "支付中" else "支付宝支付",
                    Modifier.fillMaxWidth(),
                    enabled = !paying && !orderBusy,
                    onClick = { runtimeActions.payCurrentWasherOrderWithAlipay(autoStartAfterPayment) }
                )
                PrimaryGradientButton(
                    if (orderBusy) "处理中" else "取消订单",
                    Modifier.fillMaxWidth(),
                    enabled = !paying && !orderBusy,
                    onClick = { runtimeActions.cancelCurrentWasherOrder() }
                )
            } else if (canStart) {
                PrimaryGradientButton(
                    if (orderBusy) "启动中" else "启动洗衣机",
                    Modifier.fillMaxWidth(),
                    enabled = !paying && !orderBusy,
                    onClick = { runtimeActions.startCurrentWasherOrder() }
                )
                PrimaryGradientButton(
                    if (orderBusy) "处理中" else "取消订单",
                    Modifier.fillMaxWidth(),
                    enabled = !paying && !orderBusy,
                    onClick = { runtimeActions.cancelCurrentWasherOrder() }
                )
            } else if (canStop) {
                PrimaryGradientButton(
                    if (orderBusy) "处理中" else "提前停止",
                    Modifier.fillMaxWidth(),
                    enabled = !paying && !orderBusy,
                    onClick = { runtimeActions.stopCurrentWasherOrder() }
                )
            }
        }
    }
}

private fun formatSeconds(seconds: Int): String {
    val safe = seconds.coerceAtLeast(0)
    val minutes = safe / 60
    val remain = safe % 60
    return String.format(java.util.Locale.CHINA, "%02d:%02d", minutes, remain)
}

@Composable
private fun OptionSection(
    icon: String,
    title: String,
    tail: String,
    options: List<Triple<String, String?, String>>,
    selected: Int,
    compact: Boolean = false,
    onSelected: (Int) -> Unit = {}
) {
    SectionCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(10.dp)) {
        Column {
            SectionTitle(icon, title, tail = tail)
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                options.forEachIndexed { index, option ->
                    Box(Modifier.weight(1f).shuiPressable(scale = ShuiMotion.SoftPressedScale) { onSelected(index) }) {
                        OptionCard(
                            title = option.first,
                            subtitle = option.second,
                            icon = option.third,
                            selected = index == selected,
                            color = if (compact && index > 0) ShuiColors.Blue else ShuiColors.Primary,
                            iconColor = optionColor(title, index),
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            }
        }
    }
}

private fun washerModelIcon(index: Int): String {
    return listOf("strong", "shirt", "bolt", "spiral").getOrElse(index) { "shirt" }
}

private fun formatFenAmount(priceFen: Int): String {
    return "¥" + String.format(java.util.Locale.CHINA, "%.2f", priceFen / 100.0)
}

private fun optionColor(sectionTitle: String, index: Int): Color {
    return when {
        sectionTitle.contains("套餐") -> listOf(ShuiColors.Primary, ShuiColors.Blue, ShuiColors.Orange, Color(0xFF8D62E8))[index]
        sectionTitle.contains("温度") -> listOf(ShuiColors.Primary, ShuiColors.Blue, ShuiColors.Orange, ShuiColors.Primary)[index]
        sectionTitle.contains("洗衣液") || sectionTitle.contains("除菌液") -> if (index == 0) ShuiColors.Primary else ShuiColors.Blue
        else -> ShuiColors.Primary
    }
}

@Composable
private fun AutoStartNoticeCard(
    enabled: Boolean,
    onEnabledChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    SectionCard(modifier = modifier, contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("★", color = ShuiColors.Primary, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text("支付成功后会自动启动洗衣机", color = ShuiColors.DeepText, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Text(
                    if (enabled) "支付宝返回成功后等待 3 秒发送启动指令" else "关闭后只保留预约，需要你手动启动",
                    color = ShuiColors.MutedText,
                    fontSize = 12.sp
                )
            }
            Switch(
                checked = enabled,
                onCheckedChange = onEnabledChange,
                colors = SwitchDefaults.colors(
                    checkedThumbColor = Color.White,
                    checkedTrackColor = ShuiColors.Primary,
                    uncheckedThumbColor = Color.White,
                    uncheckedTrackColor = Color(0xFFC2A3A9)
                )
            )
        }
    }
}

@Composable
private fun PriceBar(
    amount: String,
    enabled: Boolean,
    buttonText: String,
    onCreate: () -> Unit,
    modifier: Modifier = Modifier
) {
    SectionCard(
        modifier = modifier
            .padding(bottom = 10.dp)
            .dashedBorder(ShuiColors.PrimaryLight, 16.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 14.dp, vertical = 10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("预计价格", color = ShuiColors.DeepText, fontSize = 14.sp)
                Text(amount, color = ShuiColors.Primary, fontSize = 31.sp, fontWeight = FontWeight.Bold)
            }
            PrimaryGradientButton(buttonText, Modifier.width(132.dp).height(52.dp), enabled = enabled, onClick = onCreate)
        }
    }
}

@Composable
private fun ProfileScreen(
    selectedTab: MainTab,
    runtimeState: ShuiRuntimeState,
    onTabSelected: (MainTab) -> Unit,
    onOpenZhuliAccount: () -> Unit = {},
    onOpenUjingAccount: () -> Unit = {},
    onOpenMoreOptions: () -> Unit = {}
) {
    PrimaryPageScaffold(
        title = "我的",
        selectedTab = selectedTab,
        onTabSelected = onTabSelected,
        showSettings = true,
        character = {
            DecorativeImage(
                R.drawable.profile_top_character,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(start = 34.dp)
                    .offset(y = 10.dp)
                    .size(104.dp)
            )
        }
    ) {
        Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            AccountCard(
                title = "住理生活账号",
                accent = ShuiColors.Primary,
                titleIcon = R.drawable.shui_zhuli,
                logoRes = R.drawable.shui_zhuli,
                serviceIcon = R.drawable.shui_red_check,
                resetIcon = R.drawable.shui_red_reset,
                unsetIcon = R.drawable.shui_red_unset,
                statusIcon = R.drawable.shui_red_status,
                loginHint = "点击登录住理生活账号",
                serviceText = "检测住理服务",
                statusTitle = if (runtimeState.hotwaterPhone.isBlank()) "未登录" else "已登录：${runtimeState.hotwaterPhone}",
                statusSubtitle = "热水设备码：${runtimeState.hotwaterDeviceCode.ifBlank { "未绑定" }}",
                middleActionText = "绑定设备码",
                onOpen = onOpenZhuliAccount
            )
            AccountCard(
                title = "U净账号",
                accent = ShuiColors.Blue,
                titleIcon = R.drawable.shui_u,
                logoRes = R.drawable.shui_u,
                serviceIcon = R.drawable.shui_blue_check,
                resetIcon = R.drawable.shui_blue_reset,
                unsetIcon = R.drawable.shui_blue_unset,
                statusIcon = R.drawable.shui_blue_status,
                loginHint = "点击登录 U净账号",
                serviceText = "检测 U净服务",
                statusTitle = runtimeState.ujingAccount?.mobile?.let { "已登录：$it" } ?: "未登录",
                statusSubtitle = runtimeState.ujingAccount?.let { "服务：${it.serviceSubjectId}" } ?: "验证码登录 U净",
                middleActionText = "绑定设备码",
                onOpen = onOpenUjingAccount
            )
            MoreOptionsEntry(onOpenMoreOptions)
            Box(Modifier.fillMaxWidth().height(86.dp)) {
                DecorativeImage(R.drawable.shui_wode_bottom, Modifier.align(Alignment.BottomCenter).size(258.dp))
            }
        }
    }
}

@Composable
private fun MoreOptionsEntry(onOpen: () -> Unit) {
    SectionCard(
        modifier = Modifier.shuiPressable(scale = ShuiMotion.SoftPressedScale, onClick = onOpen),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            DecorativeImage(R.drawable.shui_red_1, Modifier.size(24.dp))
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text("更多选项", color = ShuiColors.DeepText, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                Text("权限检测、日志与诊断、导入导出", color = ShuiColors.MutedText, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Text("›", color = ShuiColors.Primary, fontSize = 24.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun UjingAccountRuntimeCard(
    runtimeState: ShuiRuntimeState,
    runtimeActions: ShuiRuntimeActions
) {
    var mobile by remember(runtimeState.ujingAccount?.mobile) {
        mutableStateOf(runtimeState.ujingAccount?.mobile ?: "")
    }
    var captcha by remember { mutableStateOf("") }
    val captchaLoading = runtimeState.ujingCaptcha.state == RuntimeTaskState.Loading
    val loginLoading = runtimeState.washerLogin.state == RuntimeTaskState.Loading
    val busy = captchaLoading || loginLoading
    val account = runtimeState.ujingAccount

    SectionCard(
        borderColor = ShuiColors.Blue.copy(alpha = .28f),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 10.dp, vertical = 8.dp)
    ) {
        Column {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                DecorativeImage(R.drawable.shui_u, Modifier.size(24.dp))
                Spacer(Modifier.width(8.dp))
                Text("U净账号", color = ShuiColors.DeepText, fontSize = 19.sp, fontWeight = FontWeight.Bold)
                Text("  ✦", color = ShuiColors.Blue.copy(alpha = .35f), fontSize = 16.sp)
                Spacer(Modifier.weight(1f))
                Box(Modifier.width(82.dp).height(1.dp).background(ShuiColors.Blue.copy(alpha = .16f)))
            }
            Spacer(Modifier.height(6.dp))
            SectionCard(borderColor = ShuiColors.Blue.copy(alpha = .18f), contentPadding = androidx.compose.foundation.layout.PaddingValues(8.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        DecorativeImage(R.drawable.shui_u, Modifier.size(42.dp))
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text(
                                account?.mobile?.let { "已登录：$it" } ?: "未登录",
                                color = ShuiColors.DeepText,
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                account?.let { "用户 ${it.userId} / 服务 ${it.serviceSubjectId}" } ?: "手机号验证码登录 U净",
                                color = ShuiColors.Brown,
                                fontSize = 11.sp,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                    OutlinedTextField(
                        value = mobile,
                        onValueChange = { mobile = it },
                        label = { Text("U净手机号") },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(
                            value = captcha,
                            onValueChange = { captcha = it },
                            label = { Text("验证码") },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            modifier = Modifier.weight(1f)
                        )
                        PrimaryGradientButton(
                            if (captchaLoading) "发送中" else "验证码",
                            Modifier.width(92.dp).height(52.dp),
                            enabled = !busy,
                            onClick = { runtimeActions.requestUjingCaptcha(mobile) }
                        )
                    }
                    PrimaryGradientButton(
                        if (loginLoading) "登录中" else "登录 U净",
                        Modifier.fillMaxWidth(),
                        enabled = !busy,
                        onClick = { runtimeActions.loginUjing(mobile, captcha) }
                    )
                    runtimeState.ujingCaptcha.message?.let { message ->
                        RuntimeStatusBanner(message, runtimeState.ujingCaptcha.state)
                    }
                    runtimeState.washerLogin.message?.let { message ->
                        RuntimeStatusBanner(message, runtimeState.washerLogin.state)
                    }
                }
            }
        }
    }
}

@Composable
private fun OrdersScreen(
    selectedTab: MainTab,
    runtimeState: ShuiRuntimeState,
    runtimeActions: ShuiRuntimeActions,
    onTabSelected: (MainTab) -> Unit,
    onOpenDetail: () -> Unit,
    onOpenDrinking: () -> Unit
) {
    LaunchedEffect(Unit) {
        runtimeActions.loadHotwaterHistory()
    }
    var selectedCategory by remember { mutableStateOf(OrderCategory.Hotwater) }
    var nowMillis by remember { mutableStateOf(System.currentTimeMillis()) }
    LaunchedEffect(selectedCategory, runtimeState.currentWasherOrder?.orderId) {
        while (selectedCategory == OrderCategory.Washer && runtimeState.currentWasherOrder != null) {
            nowMillis = System.currentTimeMillis()
            delay(1000)
        }
    }
    LaunchedEffect(selectedCategory, runtimeState.currentWasherOrder?.orderId, runtimeState.currentWasherOrder?.status) {
        while (
            selectedCategory == OrderCategory.Washer &&
            runtimeState.currentWasherOrder != null &&
            runtimeState.currentWasherOrder.status != "50"
        ) {
            delay(30000)
            runtimeActions.refreshCurrentWasherOrder()
        }
    }

    val hotwaterOrders = runtimeState.hotwaterHistoryRecords.map { record ->
        OrderUi(
            type = "热水",
            time = record.time,
            device = "热水设备 ${record.deviceId}",
            amount = "¥${record.amount}",
            status = record.status,
            iconRes = R.drawable.shui_reshui,
            icon = "♨",
            color = when {
                record.status.contains("使用") -> ShuiColors.Blue
                record.status.contains("取消") -> ShuiColors.MutedText
                else -> ShuiColors.Primary
            }
        )
    }
    val washerOrder = runtimeState.currentWasherOrder?.let { order ->
        OrderUi(
            type = "洗衣",
            time = liveWasherOrderTime(order, nowMillis),
            device = "洗衣机 ${order.deviceNo}",
            amount = formatDisplayAmount(order.payPrice),
            status = liveWasherOrderStatus(order, nowMillis),
            iconRes = R.drawable.shui_yifu,
            icon = "衣",
            color = ShuiColors.Orange
        )
    }
    val washerHistoryOrders = runtimeState.washerOrderHistoryRecords
        .asReversed()
        .filterNot { record -> runtimeState.currentWasherOrder?.orderId == record.orderId }
        .map { record ->
            OrderUi(
                type = "洗衣",
                time = record.updatedAt,
                device = "洗衣机 ${record.deviceNo.ifBlank { record.orderId }}",
                amount = formatDisplayAmount(record.payPrice),
                status = record.status,
                iconRes = R.drawable.shui_yifu,
                icon = "衣",
                color = ShuiColors.Orange
            )
        }
    val washerOrders = listOfNotNull(washerOrder) + washerHistoryOrders
    val drinkingOrder = runtimeState.currentWaterOrder?.let { order ->
        OrderUi(
            type = "饮水",
            time = "当前订单",
            device = "饮水机 ${order.deviceNo.ifBlank { order.orderId }}",
            amount = String.format(java.util.Locale.CHINA, "¥%.2f", order.payment),
            status = order.statusRemark.ifBlank { order.orderStatusName },
            iconRes = R.drawable.shui_jieshui,
            icon = "水",
            color = ShuiColors.Blue
        )
    }
    val drinkingOrders = listOfNotNull(drinkingOrder) + runtimeState.waterOrderHistoryRecords
        .asReversed()
        .map { order ->
            OrderUi(
                type = "饮水",
                time = order.completedAt,
                device = "饮水机 ${order.deviceNo.ifBlank { order.orderId }}",
                amount = String.format(java.util.Locale.CHINA, "¥%.2f", order.payment),
                status = order.status,
                iconRes = R.drawable.shui_jieshui,
                icon = "水",
                color = ShuiColors.Blue
            )
        }
    val historyMessage = runtimeState.hotwaterHistory.message

    PrimaryPageScaffold(
        title = "历史订单",
        selectedTab = selectedTab,
        onTabSelected = onTabSelected,
        showBack = true,
        bottomCharacter = true
    ) {
        Column(Modifier.padding(top = 10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                CategoryChip(
                    "热水",
                    selectedCategory == OrderCategory.Hotwater,
                    ShuiColors.Primary,
                    Modifier.weight(1f),
                    iconRes = R.drawable.shui_reshui,
                    onClick = { selectedCategory = OrderCategory.Hotwater }
                )
                CategoryChip(
                    "饮水",
                    selectedCategory == OrderCategory.Drinking,
                    ShuiColors.Blue,
                    Modifier.weight(1f),
                    iconRes = R.drawable.shui_jieshui,
                    onClick = { selectedCategory = OrderCategory.Drinking }
                )
                CategoryChip(
                    "洗衣",
                    selectedCategory == OrderCategory.Washer,
                    ShuiColors.Orange,
                    Modifier.weight(1f),
                    iconRes = R.drawable.shui_yifu,
                    onClick = { selectedCategory = OrderCategory.Washer }
                )
            }
            if (selectedCategory == OrderCategory.Hotwater && historyMessage != null) {
                RuntimeStatusBanner(historyMessage, runtimeState.hotwaterHistory.state)
            }
            when (selectedCategory) {
                OrderCategory.Hotwater -> {
                    if (hotwaterOrders.isEmpty()) {
                        EmptyOrderRuntimeState(runtimeState.hotwaterHistory.state)
                    } else {
                        hotwaterOrders.forEach { OrderListItem(it, onClick = {}) }
                    }
                }
                OrderCategory.Drinking -> {
                    if (drinkingOrders.isEmpty()) {
                        EmptyDrinkingOrderState(runtimeState.waterOrder.state)
                    } else {
                        drinkingOrders.forEachIndexed { index, order ->
                            val openOrder: () -> Unit = if (index == 0 && drinkingOrder != null) onOpenDrinking else ({})
                            OrderListItem(order, openOrder)
                        }
                    }
                }
                OrderCategory.Washer -> {
                    if (washerOrders.isEmpty()) {
                        EmptyWasherOrderState(runtimeState.washerOrder.state)
                    } else {
                        washerOrders.forEachIndexed { index, order ->
                            OrderListItem(order, if (index == 0 && washerOrder != null) onOpenDetail else ({}))
                        }
                    }
                }
            }
        }
    }
}

private fun formatDisplayAmount(raw: String): String {
    return if (raw.startsWith("¥")) raw else "¥$raw"
}

private fun liveWasherOrderTime(order: com.kazuki.zhulihotwater.runtime.WasherOrderUi, nowMillis: Long): String {
    val remain = liveRemainSeconds(order.remainTimeSeconds, order.refreshedAtMillis, nowMillis)
    val countdown = liveRemainSeconds(order.countDownSeconds, order.refreshedAtMillis, nowMillis)
    return when {
        remain > 0 -> "预计 ${formatClockTime(nowMillis + remain * 1000L)} 结束"
        countdown > 0 -> "预约保留 ${formatSeconds(remain.coerceAtLeast(countdown))}"
        else -> "当前订单"
    }
}

private fun liveWasherOrderStatus(order: com.kazuki.zhulihotwater.runtime.WasherOrderUi, nowMillis: Long): String {
    val remain = liveRemainSeconds(order.remainTimeSeconds, order.refreshedAtMillis, nowMillis)
    val countdown = liveRemainSeconds(order.countDownSeconds, order.refreshedAtMillis, nowMillis)
    return when {
        remain > 0 -> "${order.statusText} · 剩余 ${formatSeconds(remain)}"
        countdown > 0 -> "${order.statusText} · 保留 ${formatSeconds(countdown)}"
        else -> order.statusText
    }
}

private fun liveRemainSeconds(rawSeconds: Int, refreshedAtMillis: Long, nowMillis: Long): Int {
    if (rawSeconds <= 0) return 0
    val elapsed = ((nowMillis - refreshedAtMillis).coerceAtLeast(0L) / 1000L).toInt()
    return (rawSeconds - elapsed).coerceAtLeast(0)
}

private fun formatClockTime(timestamp: Long): String {
    return java.text.SimpleDateFormat("HH:mm", java.util.Locale.CHINA).format(java.util.Date(timestamp))
}

@Composable
private fun RuntimeStatusBanner(message: String, state: RuntimeTaskState) {
    val color = when (state) {
        RuntimeTaskState.Failure, RuntimeTaskState.LoginRequired, RuntimeTaskState.PermissionRequired -> ShuiColors.Orange
        RuntimeTaskState.Success -> ShuiColors.Green
        else -> ShuiColors.Primary
    }
    SectionCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 9.dp)) {
        AnimatedContent(
            targetState = message to color,
            transitionSpec = { shuiPageTransform(this) },
            label = "runtimeStatusBannerMotion"
        ) { (animatedMessage, animatedColor) ->
            Text(
                text = animatedMessage,
                color = animatedColor,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun EmptyOrderRuntimeState(state: RuntimeTaskState) {
    SectionCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp)) {
        Text(
            text = if (state == RuntimeTaskState.Loading) "正在加载订单..." else "暂无可显示订单",
            color = ShuiColors.MutedText,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun EmptyDrinkingOrderState(state: RuntimeTaskState) {
    SectionCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp)) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(if (state == RuntimeTaskState.Loading) "正在刷新饮水订单" else "暂无饮水订单", color = ShuiColors.DeepText, fontSize = 16.sp, fontWeight = FontWeight.Bold)
            Text(
                "扫描饮水机二维码后创建接水订单，接水开始和停止由你在机器上按按钮决定。",
                color = ShuiColors.MutedText,
                fontSize = 13.sp,
                textAlign = TextAlign.Center,
                lineHeight = 18.sp
            )
        }
    }
}

@Composable
private fun EmptyWasherOrderState(state: RuntimeTaskState) {
    SectionCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp)) {
        Text(
            text = if (state == RuntimeTaskState.Loading) "正在恢复洗衣订单..." else "暂无当前洗衣订单，请先扫码洗衣机并创建订单",
            color = ShuiColors.MutedText,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun CategoryChip(
    text: String,
    selected: Boolean,
    color: Color,
    modifier: Modifier,
    iconRes: Int? = null,
    onClick: () -> Unit = {}
) {
    Box(
        modifier = modifier
            .height(44.dp)
            .clip(RoundedCornerShape(9.dp))
            .background(if (selected) color else Color.White.copy(alpha = .65f))
            .border(1.dp, color.copy(alpha = .3f), RoundedCornerShape(9.dp))
            .shuiPressable(scale = ShuiMotion.SoftPressedScale, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
            if (iconRes != null) {
                DecorativeImage(iconRes, Modifier.size(22.dp))
                Spacer(Modifier.width(4.dp))
            }
            Text(text, color = if (selected) Color.White else ShuiColors.DeepText, fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1)
        }
    }
}

@Composable
private fun OrderDetailScreen(
    selectedTab: MainTab,
    runtimeState: ShuiRuntimeState,
    runtimeActions: ShuiRuntimeActions,
    onBack: () -> Unit,
    onTabSelected: (MainTab) -> Unit
) {
    PrimaryPageScaffold(
        title = "订单详情",
        selectedTab = selectedTab,
        onTabSelected = onTabSelected,
        showBack = true,
        onBack = onBack,
        bottomCharacter = true
    ) {
        Column(Modifier.padding(top = 28.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (runtimeState.currentWasherOrder == null) {
                SectionCard(modifier = Modifier.padding(horizontal = 8.dp), contentPadding = androidx.compose.foundation.layout.PaddingValues(22.dp)) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("暂无当前洗衣订单", color = ShuiColors.DeepText, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                        Text(
                            "请先扫码选择洗衣机并创建订单，或等待 App 启动时恢复进行中的订单。",
                            color = ShuiColors.MutedText,
                            fontSize = 13.sp,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            } else {
                CurrentWasherOrderPaymentCard(runtimeState, runtimeActions)
                PrimaryGradientButton(
                    if (runtimeState.washerOrder.state == RuntimeTaskState.Loading) "刷新中" else "刷新订单状态",
                    Modifier.fillMaxWidth().padding(horizontal = 8.dp),
                    enabled = runtimeState.washerOrder.state != RuntimeTaskState.Loading &&
                        runtimeState.washerPayment.state != RuntimeTaskState.PaymentInProgress,
                    onClick = { runtimeActions.refreshCurrentWasherOrder() }
                )
                runtimeState.washerOrder.message?.let { message ->
                    RuntimeStatusBanner(message, runtimeState.washerOrder.state)
                }
            }
        }
    }
}

@Composable
private fun DetailRow(label: String, value: String) {
    Row {
        Text(label, color = ShuiColors.DeepText, fontSize = 16.sp)
        Spacer(Modifier.weight(1f))
        Text(value, color = ShuiColors.DeepText, fontSize = 16.sp, fontWeight = if (value.startsWith("¥")) FontWeight.Bold else FontWeight.Normal)
    }
}

@Composable
private fun DevicesScreen(
    selectedTab: MainTab,
    runtimeState: ShuiRuntimeState,
    runtimeActions: ShuiRuntimeActions,
    onTabSelected: (MainTab) -> Unit,
    onOpenOrder: () -> Unit,
    onAdd: () -> Unit,
    onMenu: (LocalDeviceShortcut) -> Unit,
    onOpenDrinking: (LocalDeviceShortcut) -> Unit,
    onOpenEmpty: () -> Unit
) {
    val devices = runtimeState.localDevices.filter { it.deviceType == LocalDeviceType.Washer || it.deviceType == LocalDeviceType.DrinkingWater }
    val refresh = { runtimeActions.refreshLocalDevices() }
    val lastRefreshed = runtimeState.localDevicesLastRefreshed.ifBlank { "未刷新" }
    PrimaryPageScaffold(
        title = "选择设备",
        selectedTab = selectedTab,
        onTabSelected = onTabSelected,
        showBack = true,
        showAdd = true,
        onAdd = onAdd,
        bottomCharacter = true
    ) {
        Column(
            Modifier
                .padding(top = 10.dp)
                .pointerInput(devices.size) {
                    var pullDistance = 0f
                    detectVerticalDragGestures(
                        onVerticalDrag = { _, dragAmount ->
                            if (dragAmount > 0f) pullDistance += dragAmount
                        },
                        onDragEnd = {
                            if (pullDistance > 90f) refresh()
                            pullDistance = 0f
                        },
                        onDragCancel = { pullDistance = 0f }
                    )
                },
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            RefreshBar(lastRefreshed = lastRefreshed, onRefresh = refresh)
            if (devices.isEmpty()) {
                EmptyDeviceRuntimeState()
            }
            devices.forEachIndexed { index, device ->
                DeviceListItem(
                    device = DeviceUi(
                        name = deviceDisplayName(device, index),
                        id = device.deviceNo ?: shortDeviceId(device.id),
                        type = when (device.deviceType) {
                            LocalDeviceType.DrinkingWater -> "饮水快捷入口"
                            LocalDeviceType.Washer -> device.storeName ?: "洗衣快捷入口"
                            LocalDeviceType.Unknown -> "本地快捷入口"
                        },
                        status = device.lastStatus ?: "未知",
                        statusColor = when {
                            device.deviceType == LocalDeviceType.DrinkingWater -> ShuiColors.Blue
                            device.lastStatus == "可下单" -> ShuiColors.Green
                            device.lastStatus?.contains("运行") == true -> ShuiColors.Blue
                            else -> ShuiColors.Orange
                        },
                        imageRes = when (device.deviceType) {
                            LocalDeviceType.DrinkingWater -> R.drawable.shui_jieshui
                            LocalDeviceType.Washer, LocalDeviceType.Unknown -> R.drawable.washer_machine
                        }
                    ),
                    onMenu = { onMenu(device) },
                    onOpen = {
                        if (device.deviceType == LocalDeviceType.DrinkingWater) {
                            onOpenDrinking(device)
                            return@DeviceListItem
                        }
                        val qr = device.qrUrl
                        if (qr.isNullOrBlank()) {
                            onMenu(device)
                        } else {
                            runtimeActions.scanWasher(qr)
                            onOpenOrder()
                        }
                    }
                )
            }
            Spacer(Modifier.height(10.dp))
            Box(Modifier.fillMaxWidth().height(44.dp).shuiPressable(onClick = onOpenEmpty))
        }
    }
}

private fun deviceDisplayName(device: LocalDeviceShortcut, index: Int): String {
    val fallback = if (device.deviceType == LocalDeviceType.DrinkingWater) {
        "饮水机A-${(index + 1).toString().padStart(2, '0')}"
    } else {
        "洗衣机A-${(index + 1).toString().padStart(2, '0')}"
    }
    return device.customName.takeIf { it.isNotBlank() } ?: fallback
}

private fun shortDeviceId(id: String): String {
    return if (id.length <= 12) id else "${id.take(8)}..."
}

@Composable
private fun RefreshBar(
    lastRefreshed: String = "未刷新",
    onRefresh: () -> Unit = {}
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(ShuiColors.WeakPink.copy(alpha = .55f))
            .border(1.dp, ShuiColors.CardBorder.copy(alpha = .45f), RoundedCornerShape(10.dp))
            .shuiPressable(scale = ShuiMotion.SoftPressedScale, onClick = onRefresh)
            .padding(horizontal = 12.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("↻", color = ShuiColors.Primary, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.width(7.dp))
        Text("最近刷新：$lastRefreshed", color = ShuiColors.DeepText, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Spacer(Modifier.weight(1f))
        Text("↻ 刷新", color = ShuiColors.Primary, fontSize = 12.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun EmptyDevicesScreen(
    selectedTab: MainTab,
    onBack: () -> Unit,
    onAdd: () -> Unit,
    onTabSelected: (MainTab) -> Unit
) {
    PrimaryPageScaffold(
        title = "选择设备",
        selectedTab = selectedTab,
        onTabSelected = onTabSelected,
        showBack = true,
        onBack = onBack,
        showAdd = true,
        onAdd = onAdd
    ) {
        Column(Modifier.padding(top = 10.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            RefreshBar()
            Box(Modifier.fillMaxWidth().height(330.dp), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    DecorativeImage(R.drawable.empty_box, Modifier.size(160.dp))
                    Text("暂无设备", color = ShuiColors.DeepText, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    Text("点击右上角 + 添加设备", color = ShuiColors.MutedText, fontSize = 13.sp)
                }
            }
        }
    }
}

@Composable
private fun EmptyDeviceRuntimeState() {
    SectionCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp)) {
        Text(
            text = "暂无本地设备快捷入口，请先扫码添加",
            color = ShuiColors.MutedText,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun EditDeviceNameDialog(
    device: LocalDeviceShortcut,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit
) {
    var name by remember(device.id) { mutableStateOf(device.customName) }
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = .48f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.Center
    ) {
        SectionCard(
            modifier = Modifier
                .padding(horizontal = 34.dp)
                .clickable(onClick = {}),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("编辑名称", color = ShuiColors.DeepText, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    singleLine = true,
                    label = { Text("洗衣机名称") },
                    modifier = Modifier.fillMaxWidth()
                )
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    PrimaryGradientButton("取消", Modifier.weight(1f), onClick = onDismiss)
                    PrimaryGradientButton(
                        "保存",
                        Modifier.weight(1f),
                        enabled = name.trim().isNotEmpty(),
                        onClick = { onSave(name) }
                    )
                }
            }
        }
    }
}

@Composable
private fun HotwaterDetailScreen(
    selectedTab: MainTab,
    runtimeState: ShuiRuntimeState,
    runtimeActions: ShuiRuntimeActions,
    onBack: () -> Unit,
    onTabSelected: (MainTab) -> Unit
) {
    PrimaryPageScaffold(
        title = "热水详情",
        selectedTab = selectedTab,
        onTabSelected = onTabSelected,
        showBack = true,
        onBack = onBack
    ) {
        Column(Modifier.padding(top = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SectionCard {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    SectionTitle(icon = "hot", title = "当前热水")
                    RuntimeStatusBanner(runtimeState.hotwaterStart.message ?: "暂无热水任务", runtimeState.hotwaterStart.state)
                    runtimeState.hotwaterStop.message?.let { RuntimeStatusBanner(it, runtimeState.hotwaterStop.state) }
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        PrimaryGradientButton("开热水", Modifier.weight(1f), enabled = runtimeState.hotwaterStart.state != RuntimeTaskState.Loading) {
                            runtimeActions.startHotwater()
                        }
                        PrimaryGradientButton("关热水", Modifier.weight(1f), enabled = runtimeState.hotwaterStop.state != RuntimeTaskState.Loading) {
                            runtimeActions.stopHotwater()
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AccountDetailScreen(
    selectedTab: MainTab,
    kind: AccountKind,
    runtimeState: ShuiRuntimeState,
    runtimeActions: ShuiRuntimeActions,
    onBack: () -> Unit,
    onTabSelected: (MainTab) -> Unit
) {
    PrimaryPageScaffold(
        title = if (kind == AccountKind.Zhuli) "住理生活" else "U净账号",
        selectedTab = selectedTab,
        onTabSelected = onTabSelected,
        showBack = true,
        onBack = onBack
    ) {
        if (kind == AccountKind.Zhuli) {
            ZhuliAccountDetail(runtimeState, runtimeActions)
        } else {
            UjingAccountDetail(runtimeState, runtimeActions)
        }
    }
}

@Composable
private fun ZhuliAccountDetail(
    runtimeState: ShuiRuntimeState,
    runtimeActions: ShuiRuntimeActions
) {
    var phone by remember(runtimeState.hotwaterPhone) { mutableStateOf(runtimeState.hotwaterPhone) }
    var password by remember { mutableStateOf("") }
    var deviceCode by remember(runtimeState.hotwaterDeviceCode) { mutableStateOf(runtimeState.hotwaterDeviceCode) }
    val busy = runtimeState.hotwaterLogin.state == RuntimeTaskState.Loading
    Column(Modifier.padding(top = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionCard {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SectionTitle(icon = "home", title = "住理生活")
                RuntimeStatusBanner(runtimeState.hotwaterLogin.message ?: "未登录", runtimeState.hotwaterLogin.state)
                OutlinedTextField(
                    value = phone,
                    onValueChange = { phone = it },
                    label = { Text("手机号") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("密码") },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth()
                )
                PrimaryGradientButton(
                    if (busy) "登录中" else "点击登录",
                    Modifier.fillMaxWidth(),
                    enabled = !busy,
                    onClick = { runtimeActions.loginHotwater(phone, password) }
                )
            }
        }
        SectionCard {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SectionTitle(icon = "hot", title = "绑定设备码")
                OutlinedTextField(
                    value = deviceCode,
                    onValueChange = { deviceCode = it },
                    label = { Text("热水设备码") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    PrimaryGradientButton("绑定设备码", Modifier.weight(1f)) {
                        runtimeActions.bindHotwaterDeviceCode(deviceCode)
                    }
                    PrimaryGradientButton("查看状态", Modifier.weight(1f)) {
                        runtimeActions.checkHotwaterStatus()
                    }
                }
                Text(
                    "当前设备码：${runtimeState.hotwaterDeviceCode.ifBlank { "未绑定" }}",
                    color = ShuiColors.MutedText,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@Composable
private fun UjingAccountDetail(
    runtimeState: ShuiRuntimeState,
    runtimeActions: ShuiRuntimeActions
) {
    var mobile by remember(runtimeState.ujingAccount?.mobile) {
        mutableStateOf(runtimeState.ujingAccount?.mobile ?: "")
    }
    var captcha by remember { mutableStateOf("") }
    val captchaLoading = runtimeState.ujingCaptcha.state == RuntimeTaskState.Loading
    val loginLoading = runtimeState.washerLogin.state == RuntimeTaskState.Loading
    val busy = captchaLoading || loginLoading
    Column(Modifier.padding(top = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionCard {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SectionTitle(icon = "U", title = "U净账号")
                RuntimeStatusBanner(runtimeState.washerLogin.message ?: "未登录", runtimeState.washerLogin.state)
                runtimeState.ujingCaptcha.message?.let { RuntimeStatusBanner(it, runtimeState.ujingCaptcha.state) }
                OutlinedTextField(
                    value = mobile,
                    onValueChange = { mobile = it },
                    label = { Text("手机号") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    modifier = Modifier.fillMaxWidth()
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        value = captcha,
                        onValueChange = { captcha = it },
                        label = { Text("验证码") },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier.weight(1f)
                    )
                    PrimaryGradientButton(
                        if (captchaLoading) "发送中" else "验证码",
                        Modifier.width(92.dp).height(52.dp),
                        enabled = !busy,
                        onClick = { runtimeActions.requestUjingCaptcha(mobile) }
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    PrimaryGradientButton(
                        if (loginLoading) "登录中" else "点击登录",
                        Modifier.weight(1f),
                        enabled = !busy,
                        onClick = { runtimeActions.loginUjing(mobile, captcha) }
                    )
                    PrimaryGradientButton("查看状态", Modifier.weight(1f), enabled = !busy) {
                        runtimeActions.checkUjingStatus()
                    }
                }
                Text(
                    runtimeState.ujingAccount?.let { "账号：${it.mobile} / 用户 ${it.userId}" } ?: "暂无已登录账号",
                    color = ShuiColors.MutedText,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

@Composable
private fun MoreOptionsScreen(
    selectedTab: MainTab,
    runtimeActions: ShuiRuntimeActions,
    onBack: () -> Unit,
    onTabSelected: (MainTab) -> Unit
) {
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current
    val scope = rememberCoroutineScope()
    var showAbout by remember { mutableStateOf(false) }
    var checkingVersion by remember { mutableStateOf(false) }
    var versionResult by remember { mutableStateOf<VersionCheckResult?>(null) }
    val prefs = context.getSharedPreferences("zhuli_hotwater", Context.MODE_PRIVATE)
    val openSettings = {
        context.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", context.packageName, null)
            }
        )
    }
    val openLogs = {
        context.startActivity(Intent(context, LogActivity::class.java))
    }
    val exportDevices = {
        val raw = prefs.getString("local_devices", "[]") ?: "[]"
        clipboard.setText(AnnotatedString(raw))
        Toast.makeText(context, "设备列表已复制到剪贴板", Toast.LENGTH_SHORT).show()
    }
    val importDevices = {
        val raw = clipboard.getText()?.text.orEmpty()
        val valid = runCatching { JSONArray(raw) }.isSuccess
        if (valid) {
            prefs.edit().putString("local_devices", raw).apply()
            runtimeActions.refreshLocalDevices()
            Toast.makeText(context, "设备列表已从剪贴板导入", Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(context, "剪贴板不是有效设备列表 JSON", Toast.LENGTH_SHORT).show()
        }
    }
    val checkVersion = {
        if (!checkingVersion) {
            checkingVersion = true
            scope.launch {
                versionResult = withContext(Dispatchers.IO) {
                    checkLatestGithubVersion(context.applicationContext)
                }
                checkingVersion = false
            }
        }
    }
    PrimaryPageScaffold(
        title = "更多选项",
        selectedTab = selectedTab,
        onTabSelected = onTabSelected,
        showBack = true,
        onBack = onBack
    ) {
        Column(Modifier.padding(top = 18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            MoreOptionRow("权限检测", "打开系统应用权限设置", openSettings)
            MoreOptionRow("日志与诊断", "查看本地运行日志", openLogs)
            MoreOptionRow(
                "检查版本",
                if (checkingVersion) "正在连接 GitHub Releases" else "当前版本 ${appVersionName(context)}",
                checkVersion
            )
            MoreOptionRow("导出洗衣机设备列表", "复制本地设备 JSON 到剪贴板", exportDevices)
            MoreOptionRow("导入洗衣机设备列表", "从剪贴板恢复本地设备 JSON", importDevices)
            MoreOptionRow("关于", "版本、说明与支持范围", { showAbout = true })
        }
    }
    if (showAbout) {
        AboutDialog(onDismiss = { showAbout = false })
    }
    versionResult?.let { result ->
        VersionCheckDialog(
            result = result,
            onDismiss = { versionResult = null },
            onOpen = {
                val url = result.downloadUrl.ifBlank { result.releaseUrl }
                if (url.isNotBlank()) {
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                }
                versionResult = null
            }
        )
    }
}

@Composable
private fun VersionCheckDialog(
    result: VersionCheckResult,
    onDismiss: () -> Unit,
    onOpen: () -> Unit
) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = .46f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.Center
    ) {
        SectionCard(
            modifier = Modifier
                .padding(horizontal = 26.dp)
                .clickable(enabled = false) {},
            contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp)
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                DecorativeImage(R.drawable.sleep, Modifier.size(86.dp))
                Text(
                    when {
                        result.error != null -> "版本检查失败"
                        result.updateAvailable -> "发现新版本"
                        else -> "已经是最新版"
                    },
                    color = ShuiColors.DeepText,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    versionDialogText(result),
                    color = ShuiColors.MutedText,
                    fontSize = 14.sp,
                    lineHeight = 21.sp,
                    textAlign = TextAlign.Center,
                    maxLines = 8,
                    overflow = TextOverflow.Ellipsis
                )
                if (result.updateAvailable && result.error == null) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        PrimaryGradientButton("稍后", Modifier.weight(1f), onClick = onDismiss)
                        PrimaryGradientButton("获取最新版", Modifier.weight(1f), onClick = onOpen)
                    }
                } else {
                    PrimaryGradientButton("知道啦", Modifier.fillMaxWidth(), onClick = onDismiss)
                }
            }
        }
    }
}

private fun versionDialogText(result: VersionCheckResult): String {
    result.error?.let {
        return "当前版本：${result.currentVersion}\n$it"
    }
    return if (result.updateAvailable) {
        val notes = result.notes.trim().take(180).ifBlank { "打开 GitHub Release 查看更新说明。" }
        "当前版本：${result.currentVersion}\n最新版本：${result.latestVersion}\n$notes"
    } else {
        "当前版本：${result.currentVersion}\n最新版本：${result.latestVersion.ifBlank { result.currentVersion }}"
    }
}

private fun checkLatestGithubVersion(context: Context): VersionCheckResult {
    val current = appVersionName(context)
    return try {
        val conn = (URL("https://api.github.com/repos/amamiyakazuki/FlandreSY/releases/latest").openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 12000
            readTimeout = 12000
            setRequestProperty("Accept", "application/vnd.github+json")
            setRequestProperty("User-Agent", "FlandreSY/${current}")
        }
        val code = conn.responseCode
        val stream = if (code in 200..299) conn.inputStream else conn.errorStream
        val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        if (code == 404) {
            return VersionCheckResult(
                currentVersion = current,
                error = "GitHub Releases 里还没有发布版本。公开仓库后，请先创建一个 Release 并上传签名 APK。"
            )
        }
        if (code !in 200..299) {
            return VersionCheckResult(currentVersion = current, error = "GitHub 返回 HTTP $code")
        }
        val json = JSONObject(text)
        val latestTag = json.optString("tag_name").ifBlank { json.optString("name") }
        val releaseUrl = json.optString("html_url")
        val notes = json.optString("body")
        val assets = json.optJSONArray("assets")
        var apkUrl = ""
        if (assets != null) {
            for (i in 0 until assets.length()) {
                val asset = assets.optJSONObject(i) ?: continue
                val name = asset.optString("name")
                if (name.endsWith(".apk", ignoreCase = true)) {
                    apkUrl = asset.optString("browser_download_url")
                    break
                }
            }
        }
        val latest = latestTag.removePrefix("v").removePrefix("V")
        VersionCheckResult(
            currentVersion = current,
            latestVersion = latest.ifBlank { latestTag },
            releaseUrl = releaseUrl,
            downloadUrl = apkUrl,
            notes = notes,
            updateAvailable = isVersionNewer(latest, current)
        )
    } catch (e: Exception) {
        VersionCheckResult(
            currentVersion = current,
            error = e.message ?: "无法连接 GitHub，请稍后再试"
        )
    }
}

@Suppress("DEPRECATION")
private fun appVersionName(context: Context): String {
    return runCatching {
        context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "1.0.0"
    }.getOrDefault("1.0.0")
}

private fun isVersionNewer(latest: String, current: String): Boolean {
    val latestParts = latest.toVersionParts()
    val currentParts = current.toVersionParts()
    val max = maxOf(latestParts.size, currentParts.size, 3)
    for (i in 0 until max) {
        val left = latestParts.getOrElse(i) { 0 }
        val right = currentParts.getOrElse(i) { 0 }
        if (left != right) return left > right
    }
    return false
}

private fun String.toVersionParts(): List<Int> {
    return trim()
        .removePrefix("v")
        .removePrefix("V")
        .split(".", "-", "_")
        .mapNotNull { part -> part.takeWhile { it.isDigit() }.toIntOrNull() }
}

@Composable
private fun AboutDialog(onDismiss: () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = .46f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.Center
    ) {
        SectionCard(
            modifier = Modifier
                .padding(horizontal = 28.dp)
                .clickable(enabled = false) {},
            contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp)
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                DecorativeImage(R.drawable.sleep, Modifier.size(92.dp))
                Spacer(Modifier.height(8.dp))
                Text("芙兰水衣", color = ShuiColors.DeepText, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                Text(
                    "版本 1.0.0\n当前支持住理热水、U净洗衣与饮水流程；洗衣支付暂时只支持支付宝。",
                    color = ShuiColors.MutedText,
                    fontSize = 14.sp,
                    lineHeight = 21.sp,
                    textAlign = TextAlign.Center
                )
                Spacer(Modifier.height(16.dp))
                PrimaryGradientButton("知道啦", Modifier.fillMaxWidth(), onClick = onDismiss)
            }
        }
    }
}

@Composable
private fun MoreOptionRow(title: String, subtitle: String, onClick: () -> Unit) {
    SectionCard(
        modifier = Modifier.shuiPressable(scale = ShuiMotion.SoftPressedScale, onClick = onClick),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 14.dp, vertical = 13.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(title, color = ShuiColors.DeepText, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                Text(subtitle, color = ShuiColors.MutedText, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Text("›", color = ShuiColors.Primary, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun DrinkingWaterScreen(
    selectedTab: MainTab,
    cd: String,
    runtimeState: ShuiRuntimeState,
    runtimeActions: ShuiRuntimeActions,
    onBack: () -> Unit,
    onCompleted: () -> Unit,
    onTabSelected: (MainTab) -> Unit
) {
    val ready = runtimeState.currentWaterReady
    val order = runtimeState.currentWaterOrder
    val busy = runtimeState.waterOrder.state == RuntimeTaskState.Loading
    LaunchedEffect(order?.orderId) {
        if (order != null) {
            runtimeActions.refreshCurrentDrinkingWaterOrder()
        }
    }
    LaunchedEffect(runtimeState.waterOrder.state, runtimeState.currentWaterOrder, runtimeState.waterOrder.message) {
        if (
            runtimeState.waterOrder.state == RuntimeTaskState.Success &&
            runtimeState.currentWaterOrder == null &&
            runtimeState.waterOrder.message?.contains("已完成") == true
        ) {
            onCompleted()
        }
    }
    PrimaryPageScaffold(
        title = "饮水接单",
        selectedTab = selectedTab,
        onTabSelected = onTabSelected,
        showBack = true,
        onBack = onBack
    ) {
        Column(
            Modifier.padding(top = 14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            runtimeState.waterScan.message?.let {
                RuntimeStatusBanner(it, runtimeState.waterScan.state)
            }
            runtimeState.waterOrder.message?.let {
                RuntimeStatusBanner(it, runtimeState.waterOrder.state)
            }
            SectionCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        DecorativeImage(R.drawable.shui_jieshui, Modifier.size(34.dp))
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text("饮水机", color = ShuiColors.DeepText, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                            Text("设备码：${ready?.cd ?: cd.ifBlank { "未识别" }}", color = ShuiColors.MutedText, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                    }
                    InfoLine("校区", ready?.serviceSubjectName?.ifBlank { "待确认" } ?: "待确认")
                    InfoLine("余额", ready?.let { formatFenAmount(it.balanceFen) } ?: "待查询")
                    if ((ready?.balanceFen ?: 0) <= 0 && ready != null) {
                        Text("余额不足，请先在官方 App 充值", color = ShuiColors.Orange, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    }
                    Text("扫码后会自动创建接水订单；请在饮水机上按按钮开始或停止接水。", color = ShuiColors.MutedText, fontSize = 13.sp, lineHeight = 19.sp)
                }
            }
            SectionCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("接水状态", color = ShuiColors.DeepText, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    if (order == null) {
                        Text(
                            "创建订单后，请在饮水机上按按钮开始接水；再次按机器按钮停止后，回到这里刷新状态。",
                            color = ShuiColors.MutedText,
                            fontSize = 13.sp,
                            lineHeight = 19.sp
                        )
                    } else {
                        InfoLine("订单号", order.orderId)
                        InfoLine("状态", order.statusRemark.ifBlank { order.orderStatusName })
                        InfoLine("设备", order.deviceNo.ifBlank { "未知" })
                        InfoLine("用水量", if (order.warmWaterMl > 0) "${order.warmWaterMl} ml" else "等待机器上报")
                        InfoLine("用时", if (order.waterSeconds > 0) "${order.waterSeconds} 秒" else "等待机器上报")
                        InfoLine("扣费", String.format(java.util.Locale.CHINA, "¥%.2f", order.payment))
                    }
                    PrimaryGradientButton(
                        "刷新状态",
                        Modifier.fillMaxWidth(),
                        enabled = !busy && order != null
                    ) {
                        runtimeActions.refreshCurrentDrinkingWaterOrder()
                    }
                }
            }
        }
    }
}

@Composable
private fun InfoLine(label: String, value: String) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, color = ShuiColors.MutedText, fontSize = 12.sp, modifier = Modifier.width(70.dp))
        Text(value, color = ShuiColors.DeepText, fontSize = 13.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Preview(widthDp = 390, heightDp = 844, showBackground = true)
@Composable
private fun AppPreview() {
    ShuiTheme { ShuiApp() }
}

@Preview(widthDp = 390, heightDp = 844, showBackground = true)
@Composable
private fun HomePreview() {
    ShuiTheme {
        HomeScreen(
            MainTab.Home,
            PreviewShuiRuntimeProvider.state,
            PreviewShuiRuntimeProvider.actions,
            {},
            {},
            {},
            {},
            {},
            {},
            {}
        )
    }
}

@Preview(widthDp = 390, heightDp = 844, showBackground = true)
@Composable
private fun WasherPreview() {
    ShuiTheme {
        AdaptivePhoneContainer {
            WasherOrderScreen(
                PreviewShuiRuntimeProvider.state,
                PreviewShuiRuntimeProvider.actions,
                {}
            )
        }
    }
}

@Preview(widthDp = 390, heightDp = 844, showBackground = true)
@Composable
private fun ProfilePreview() {
    ShuiTheme {
        ProfileScreen(
            MainTab.Profile,
            PreviewShuiRuntimeProvider.state,
            {},
            {},
            {},
            {}
        )
    }
}
