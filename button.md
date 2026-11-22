Hole Eating game

第一步
要可以移動的洞 必須在地面網格上挖一個洞
用CSGcylinder3D 當作 cylinder mesh 高度可以調很低=0.1 sides 可以12
確保關掉shadow material 要開啟 no Depth Test
stencil flags write
compare always
reference 1
render priority -1
Transparency 1.0
(Transparency 在手機端不生效 但可以把材質設透明 然後把反照濾alpha設成0)


把floor 可以使用這個stencil class
floor
透明度 alpha
depth draw mode always
stencil mode read
compare 選 not equal

第二步讓洞有深度
CSGcylinder3D 用到正下方 大小跟洞依樣但是有高度
新建一個材質(也可以選用floor 材質) 透明度將剔除模式設為 front
顏色選擇成yellow tint 可以更看清楚洞底下

第三步讓東西掉下去
先把floor加上碰撞 + 上rigid body
把floor的render priority -128 避免輔助線被吃掉
接下來是洞的物理 切割物理網格可行 但會造成很奇怪的效果 而且很慢
所以使用一個帶洞的碰撞體 做為第二層地面物體 然後移動他就可以
通過swap物體的collision mask 讓他只跟其中一個碰撞
洞也要可以移動所以新建一個rigidbody 3D 然後add洞mesh進去
然後我們要給帶洞的地面製作 collision mesh(meshInstance 3D)
把mesh命名為lip 調整大小讓他剛好在洞的外圍 可以加點material跟color
可以自己調形狀(或是快速Demo 先用torus mesh) 把大小match 洞 size
然後往下移 用mesh menu建立碰撞形狀 因為洞會移動 記得選擇 multiple convex (trimesh在移動物體上會有嚴重的經度問題)
然後可以複製並調整碰撞形狀更像洞 然後增加4個box collision shape對齊碰撞

第四步 關鍵
打開rigidbody 打開collisions settgin 我們需要讓他自己有一個物理層
可以設定在第五層 rename to hole
然後洞的gravity 設成0
然後增加一個area3D 新增一個collisionSahde3D create sphereShape3D 讓他略小於洞的box collision plane
然後collision mask設2

然後把hole_body 加一個script
寫兩個flags hole flags 跟normal flags
選area3D connect body enter 跟 exit signal 然後檢查物件是步是rididBody3D 然後改變body.collision_mask = hole_flags
離開的時候在改回normal

接下來把要掉進洞的物理選擇成為然後collision layer 2 mask 1,2

然後hole不和任何東西發生碰撞所以不設定mask 跟兩個地面高步要一致  然後增加collision shape在洞的底部 腳本寫把碰觸到的物體都destroy 然後確定mask能檢測到掉落的物體

然後hole要加上跟隨mouse 跟把洞加上shader