# Zoom AI 数字人替身：使用说明

目标：开 Zoom 会时，摄像头画面里是一个用你自己的视频做出来的数字人，麦克风静音。人可以不在电脑前。

用的是开源项目 LiveTalking(Apache-2.0 许可，免费，全部在自己电脑上跑)。它拿你的一小段视频当形象：平时来回播放这段视频；在控制页输入文字，它会用合成语音读出来，嘴型跟着动。画面通过 OBS 的"虚拟摄像头"送进 Zoom，Zoom 把它当作普通摄像头使用。

**只支持 Windows + NVIDIA 显卡。Mac 用不了，没有 NVIDIA 显卡的 Windows 电脑也用不了。**

## 0. 下载

点本页右上方绿色的 **Code** 按钮 → **Download ZIP**，解压。所有脚本都和这份说明在同一个文件夹里。在这个文件夹的空白处按住 Shift 点右键，选"在此处打开 PowerShell 窗口"，然后运行下面的命令。

这个仓库只有安装脚本和说明，不含 LiveTalking 本体、模型和任何人的视频；这些都由 `install.ps1` 在你的电脑上从官方来源下载。

**先把整个文件夹放到路径短、不含中文的位置**(例如 `C:\zoom-standin`)，路径太长会导致安装失败。

---

## 1. 需要什么

- Windows 10/11，NVIDIA 显卡(在 RTX 5060 8 GB 上测试通过，很轻松)。
- 约 7 GB 磁盘空间，首次安装下载约 6 GB。
- 四个软件，没有的话先装：

```powershell
winget install --id Python.Python.3.12 -e
winget install --id Git.Git -e
winget install --id OBSProject.OBSStudio -e
winget install --id Zoom.Zoom -e
```

装完后**关掉 PowerShell 重新打开**，再做下一步。OBS 装好后先打开一次、再退出(之后不需要开着它)。

## 2. 一键安装

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

它会依次：下载 LiveTalking 源码、建立独立的 Python 环境、安装显卡版 PyTorch 和其他依赖、下载口型模型和官方示例形象。全部装在本文件夹下的 `LiveTalking` 子文件夹里。耗时取决于网速，一般 10–30 分钟。中途断了重新运行即可，做完的步骤会跳过。

如果最后提示 Google Drive 下载失败，按屏幕上的提示用浏览器手动下载两个文件，放到指定文件夹后再运行一次。

## 3. 先用官方示例形象试一下

```powershell
powershell -ExecutionPolicy Bypass -File start-avatar.ps1 -Avatar wav2lip256_avatar1
```

看到 `Ready.` 后：

1. 浏览器打开 `http://localhost:8010/virtualcam.html`，输入一句话点发送，耳机/音箱里会听到它说话。
2. 打开 Zoom → 设置 → 视频，摄像头选 **OBS Virtual Camera**，能看到数字人。如果列表里没有这一项，重启 Zoom 再看。

停止：

```powershell
powershell -ExecutionPolicy Bypass -File stop-avatar.ps1
```

## 4. 做自己的形象

先用电脑摄像头录一段 **5–20 秒**的视频(Windows 自带的"相机"应用就行)：

- 摄像头固定，正脸，光线均匀，脸上不要有遮挡(手、麦克风、口罩)。
- **全程闭嘴**，不要说话。待机画面就是这段视频，嘴张着会像一直在说话。
- 可以自然眨眼、轻微晃动，但不要有大动作，不要喝水、转头走开。
- 视频会正放再倒放地循环，所以开头和结尾不需要同一个姿势。
- 穿平时开会常穿的衣服。

然后运行(路径换成你的视频)：

```powershell
powershell -ExecutionPolicy Bypass -File make-avatar.ps1 -Video "C:\Users\你\Videos\me.mp4"
```

- 5 秒的视频大约要 1 分钟。
- 数字人正在运行的话要先 `stop-avatar.ps1`，否则脚本会提示并退出(两者都要用显卡)。
- 只想用视频中的一段，加 `-Start 3 -End 15`(单位秒)。
- 重新做一次要加 `-Force`。
- **第一次运行会自动再下载一个约 86 MB 的人脸检测模型**(来自 www.adrianbulat.com，是 LiveTalking 自带的行为)。

做好后启动自己的形象：

```powershell
powershell -ExecutionPolicy Bypass -File start-avatar.ps1
```

## 5. 设置 Zoom(只需一次)

打开 Zoom 并登录，在设置里改这几项(不同版本的名称可能略有出入)：

- 视频：摄像头选 **OBS Virtual Camera**。
- 视频：取消"加入会议时关闭我的视频"。
- 音频：勾选"加入会议时自动连接电脑音频"。
- 音频：勾选"加入会议时静音我的麦克风"。

## 6. 用它开会

1. 运行 `start-avatar.ps1`，等到 `Ready.`。
2. 像平时一样点会议链接进会，确认摄像头是 OBS Virtual Camera、麦克风是静音的。
3. 开完会运行 `stop-avatar.ps1`。

**第一次用之前先自测**：自己开一个 Zoom 会议，用手机也进这个会，看看别人眼里的画面是什么样。

---

## 注意事项

- **声音进不了 Zoom**：数字人的声音只从你自己的耳机/音箱播放，会议里的人听不到。也就是说，在会议里它只是一个"在场、不说话"的画面。要让会议里听到，需要另装虚拟声卡(VB-Cable)并改启动参数，这个包里没有做。
- **被点名没有反应**：这是最大的破绽。需要应答的会议不适合用。
- **说话有 4–5 秒延迟**：从发送文字到开口。不适合用来实时应答。
- **文字会联网**：语音合成用的是微软的在线服务(EdgeTTS)，输入的文字会发给它。画面处理全部在本机。
- **没有定时自动进会**：需要自己启动数字人、自己点链接进会。电脑要一直开着、不能睡眠。
- **不要同时开 OBS 的虚拟摄像机**：同一时间只能有一个程序往虚拟摄像头送画面。OBS 本身不需要开着。
- **嘴部略糊**：说话时嘴周围比原视频模糊一点，这是这类模型的通病。
- **画面左上角有一行很小的 LiveTalking 字样**：是项目生成形象时自动加的水印。
- **卸载**：先运行 `stop-avatar.ps1`，然后删除本文件夹下的 `LiveTalking` 文件夹即可。
- **规定和知情**：有些公司、课程明确要求本人在场；用之前自己判断是否合适。

## 文件说明

| 文件 | 作用 |
|---|---|
| `install.ps1` | 一键安装，可重复运行 |
| `make-avatar.ps1` | 用一段视频生成自己的形象 |
| `start-avatar.ps1` | 启动数字人，输出到虚拟摄像头 |
| `stop-avatar.ps1` | 停止数字人 |
| `tools` | 上面脚本用到的两个小工具，不需要手动运行 |

## 哪些实测过，哪些没有

测试环境：Windows 11，RTX 5060 8 GB，已装好 Python 3.12、Git、OBS。

| 内容 | 状态 |
|---|---|
| `install.ps1` 从零安装到一个空文件夹 | 实测通过 |
| `start-avatar.ps1` / `stop-avatar.ps1`：启动官方示例形象、发文字后张嘴说话、停止 | 实测通过 |
| `make-avatar.ps1`：用一段 5 秒、1280×720 的视频生成个人形象 | 实测通过，约 40 秒 |
| `make-avatar.ps1`：视频放在带中文的路径下时的预处理 | 实测通过 |
| 用生成的个人形象启动、输出到虚拟摄像头、发文字后张嘴说话 | 实测通过 |
| 在真实 Zoom 会议里的观感 | 没有实测，请按第 6 步自测 |
