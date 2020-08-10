//
//  ViewController.m
//  滤镜特效
//
//  Created by lvAsia on 2020/8/8.
//  Copyright © 2020 yazhou lv. All rights reserved.
//

#import "ViewController.h"
#import "FilterBar.h"
#import <GLKit/GLKit.h>
typedef struct {
    GLKVector4 positionCoord;
    GLKMatrix2 textureCoord;
}FilterVertex;
@interface ViewController ()<FilterBarDelegate>
@property(nonatomic, assign) FilterVertex *vertexs;
@property(nonatomic, strong) EAGLContext *context;
@property(nonatomic, strong) CADisplayLink *displayLink;//用于刷新屏幕
@property(nonatomic, assign) NSTimeInterval timeInterval;//开始的时间戳
@property(nonatomic, assign) GLuint vertexBuffer;//顶点缓存
@property(nonatomic, assign) GLuint textureID;//顶点ID
@property (nonatomic, assign) GLuint program;//着色器程序

@end

@implementation ViewController
- (void)dealloc {
    //1.上下文释放
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    //顶点缓存区释放
    if (_vertexBuffer) {
        glDeleteBuffers(1, &_vertexBuffer);
        _vertexBuffer = 0;
    }
    //顶点数组释放
    if (_vertexs) {
        free(_vertexs);
        _vertexs = nil;
    }
}
- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    if (self.displayLink){
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor blackColor];
    [self setUpFilterBar];
    [self filterInit];
    [self startFilerAnimation];
}

- (void)setUpFilterBar{
    CGFloat filterBarWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat filterBarHeight = 100;
    CGFloat filterBarY = [UIScreen mainScreen].bounds.size.height - filterBarHeight;
    FilterBar *filerBar = [[FilterBar alloc] initWithFrame:CGRectMake(0, filterBarY, filterBarWidth, filterBarHeight)];
    filerBar.delegate = self;
    [self.view addSubview:filerBar];
    
    NSArray *dataSource = @[@"无",@"分屏_2",@"分屏_3",@"分屏_4",@"分屏_6_横",@"分屏_6_竖",@"分屏_9"];
    filerBar.itemList = dataSource;
}
- (void)filterInit{
    //初始化上下文
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.context];
    
   // 设置layer
//    CAEAGLLayer *layer = [[CAEAGLLayer alloc] init];
//    layer.frame = CGRectMake(0, 50, self.view.frame.size.width, self.view.frame.size.height-150);
//    layer.contentsScale = [[UIScreen mainScreen] scale];
//    [self.view.layer addSublayer:layer];
    
    //绑定到渲染缓冲区
    [self binrenderlayer:layer];
    
     //初始化顶点和纹理坐标
    self.vertexs = (FilterVertex *)malloc(sizeof(FilterVertex) * 4);
    self.vertexs[0] = (FilterVertex){{-1, 1, 0}, {0, 1}};
    self.vertexs[1] = (FilterVertex){{-1, -1, 0}, {0, 0}};
    self.vertexs[2] = (FilterVertex){{1, 1, 0}, {1, 1}};
    self.vertexs[3] = (FilterVertex){{1, -1, 0}, {1, 0}};
    
     //设置顶点缓冲区
    GLuint vertextBuffer;
    glGenBuffers(1, &vertextBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertextBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(FilterVertex)*4, self.vertexs, GL_STATIC_DRAW);
    self.vertexBuffer = vertextBuffer;
    
     //获取处理图片的路径
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:@"IU1" ofType:@"JPG"];
    //得到纹理
    GLuint texture2D = [self createTextureWithImageFilePath:imagePath];
    
    // 设置纹理ID
    self.textureID = texture2D;
    
    //设置默认着色器
    [self setupNormalShaderProgram];
    
    //设置视口
    glViewport(0, 0, [self drawableWidth], [self drawableHeight]);

}

- (void)setupNormalShaderProgram {
    //设置着色器程序
    [self setupShaderProgramWithName:@"normal"];
}
- (void)binrenderlayer:(CAEAGLLayer *)layer{
    //创建渲染缓冲区 帧缓冲区
    GLuint renderBuffer;
    GLuint frameBuffer;
    
    //获取帧渲染缓存区名称,绑定渲染缓存区以及将渲染缓存区与layer建立连接
    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    //获取帧缓存区名称,绑定帧缓存区以及将渲染缓存区附着到帧缓存区上
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
    
}

//从图片中加载纹理
- (GLuint)createTextureWithImageFilePath:(NSString *)filePath{
    
    //加载图片
    UIImage *image = [UIImage imageWithContentsOfFile:filePath];
    //1、将 UIImage 转换为 CGImageRef
    CGImageRef cgImageRef = [image CGImage];
    //判断图片是否获取成功
    if (!cgImageRef) {
        NSLog(@"Failed to load image");
        exit(1);
    }
    //2、读取图片的大小，宽和高
    GLuint width = (GLuint)CGImageGetWidth(cgImageRef);
    GLuint height = (GLuint)CGImageGetHeight(cgImageRef);
    //获取图片的rect
    CGRect rect = CGRectMake(0, 0, width, height);
    
    //获取图片的颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    //3.获取图片字节数 宽*高*4（RGBA）
    void *imageData = malloc(width * height * 4);
    //4.创建上下文
    /*
     参数1：data,指向要渲染的绘制图像的内存地址
     参数2：width,bitmap的宽度，单位为像素
     参数3：height,bitmap的高度，单位为像素
     参数4：bitPerComponent,内存中像素的每个组件的位数，比如32位RGBA，就设置为8
     参数5：bytesPerRow,bitmap的没一行的内存所占的比特数
     参数6：colorSpace,bitmap上使用的颜色空间  kCGImageAlphaPremultipliedLast：RGBA
     */
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    //将图片翻转过来(图片默认是倒置的)
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(context, rect);
    
    //对图片进行重新绘制，得到一张新的解压缩后的位图
    CGContextDrawImage(context, rect, cgImageRef);
    
    //设置图片纹理属性
    //5. 获取纹理ID
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    
    //6.载入纹理2D数据
    /*
     参数1：纹理模式，GL_TEXTURE_1D、GL_TEXTURE_2D、GL_TEXTURE_3D
     参数2：加载的层次，一般设置为0
     参数3：纹理的颜色值GL_RGBA
     参数4：宽
     参数5：高
     参数6：border，边界宽度
     参数7：format
     参数8：type
     参数9：纹理数据
     */
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    
    //7.设置纹理属性
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    //8.绑定纹理
    /*
     参数1：纹理维度
     参数2：纹理ID,因为只有一个纹理，给0就可以了。
     */
    glBindTexture(GL_TEXTURE_2D, 0);
    
    //9.释放context,imageData
    CGContextRelease(context);
    free(imageData);
    
    //10.返回纹理ID
    return textureID;
}
// 初始化着色器程序
- (void)setupShaderProgramWithName:(NSString *)name {
    //1. 获取着色器program
    GLuint program = [self programWithShaderName:name];
    
    //2. use Program
    glUseProgram(program);
    
    //3. 获取Position,Texture,TextureCoords 的索引位置
    GLuint positionSlot = glGetAttribLocation(program, "Position");
    GLuint textureSlot = glGetUniformLocation(program, "Texture");
    GLuint textureCoordsSlot = glGetAttribLocation(program, "TextureCoords");
    
    //4.激活纹理,绑定纹理ID
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureID);
    
    //5.纹理sample
    glUniform1i(textureSlot, 0);
    
    //6.打开positionSlot 属性并且传递数据到positionSlot中(顶点坐标)
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(FilterVertex), NULL + offsetof(FilterVertex, positionCoord));
    
    //7.打开textureCoordsSlot 属性并传递数据到textureCoordsSlot(纹理坐标)
    glEnableVertexAttribArray(textureCoordsSlot);
    glVertexAttribPointer(textureCoordsSlot, 2, GL_FLOAT, GL_FALSE, sizeof(FilterVertex), NULL + offsetof(FilterVertex, textureCoord));
    
    //8.保存program,界面销毁则释放
    self.program = program;
}
#pragma mark -shader compile and link
//将shader附着到着色程->链接->最后use
- (GLuint)programWithShaderName:(NSString *)shaderName {
    //1. 编译顶点着色器/片元着色器
    GLuint vertexShader = [self compileShaderWithName:shaderName type:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShaderWithName:shaderName type:GL_FRAGMENT_SHADER];
    
    //2. 将顶点/片元附着到program
    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    
    //3.linkProgram
    glLinkProgram(program);
    
    //4.检查是否link成功
    GLint linkSuccess;
    glGetProgramiv(program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"program链接失败：%@", messageString);
        exit(1);
    }
    //5.返回program
    return program;
}
//开启滤镜动画
- (void)startFilerAnimation{
    if(self.displayLink){
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
    self.timeInterval = 0;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(timeAction)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
}
//动画
- (void)timeAction{
    //DisplayLink 的当前时间撮
       if (self.timeInterval == 0) {
           self.timeInterval = self.displayLink.timestamp;
       }
       //使用program
       glUseProgram(self.program);
       //绑定buffer
       glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
       
       // 传入时间
       CGFloat currentTime = self.displayLink.timestamp - self.timeInterval;
       GLuint time = glGetUniformLocation(self.program, "Time");
       glUniform1f(time, currentTime);
       
       // 清除画布
       glClear(GL_COLOR_BUFFER_BIT);
       glClearColor(1, 1, 1, 1);
       
       // 重绘
       glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
       //渲染到屏幕上
       [self.context presentRenderbuffer:GL_RENDERBUFFER];
}
//编译shader代码
//获取路径 ->字符串->附着到shaer->编译
- (GLuint)compileShaderWithName:(NSString *)name type:(GLenum)shaderType {
    
    //1.获取shader 路径
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:name ofType:shaderType == GL_VERTEX_SHADER ? @"vsh" : @"fsh"];
    NSError *error;
    NSString *shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSAssert(NO, @"读取shader失败");
        exit(1);
    }
    
    //2. 创建shader->根据shaderType
    GLuint shader = glCreateShader(shaderType);
    
    //3.获取shader source
    const char *shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    glShaderSource(shader, 1, &shaderStringUTF8, &shaderStringLength);
    
    //4.编译shader
    glCompileShader(shader);
    
    //5.查看编译是否成功
    GLint compileSuccess;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shader, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"shader编译失败：%@", messageString);
        exit(1);
    }
    //6.返回shader
    return shader;
}
//获取渲染缓存区的宽
- (GLint)drawableWidth {
    GLint backingWidth;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    return backingWidth;
}
//获取渲染缓存区的高
- (GLint)drawableHeight {
    GLint backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    return backingHeight;
}
#pragma mark - FilterBarDelegate
- (void)filterBar:(FilterBar *)filterBar didScrollToIndex:(NSUInteger)index{
    if (index == 0) {
        [self setupNormalShaderProgram];
    }else if (index == 1){
        [self setupShaderProgramWithName:@"normal2"];
    }else if (index == 2){
        [self setupShaderProgramWithName:@"normal3"];
    }else if (index==3){
        [self setupShaderProgramWithName:@"normal4"];
    }else if (index==4){
        [self setupShaderProgramWithName:@"normal61"];
    }else if (index==5){
        [self setupShaderProgramWithName:@"normal6"];
    }else if (index==6){
        [self setupShaderProgramWithName:@"normal9"];
    }
    [self startFilerAnimation];
}

@end

