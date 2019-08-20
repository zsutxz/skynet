 
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";




/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- 数据库: `wx_db`
--

-- --------------------------------------------------------

--
-- 表的结构 `tb_product`
--
DROP TABLE IF EXISTS `tb_product`;
CREATE TABLE `tb_product` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '唯一id',
  `game_id` int(10) unsigned NOT NULL COMMENT '游戏代号',
  `name` char(32) DEFAULT NULL COMMENT '游戏名字',
  `pic` char(32) DEFAULT NULL COMMENT '游戏图片名字',
  `version` char(8) DEFAULT NULL COMMENT '版本号',
  `owner_id` char(32) DEFAULT NULL COMMENT '所有者id',
  `create_t` datetime DEFAULT NULL COMMENT '上线日期',
  `update_t` datetime DEFAULT NULL COMMENT '更新日期',
  `description` varchar(256) DEFAULT NULL COMMENT '游戏说明',
  `reserved_data` char(16) DEFAULT NULL COMMENT '备用值',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;

--
-- 表的结构 `tb_machine`
--
DROP TABLE IF EXISTS `tb_machine`;
CREATE TABLE IF NOT EXISTS `tb_machine` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '唯一id',
  `game_id` int(10) unsigned NOT NULL,
  `mach_id` int(6) unsigned zerofill NOT NULL,
  `company_id` int(10) unsigned ,
  `store_id` int(10) unsigned ,
  `locked` tinyint(1) unsigned NOT NULL DEFAULT '0',
  `add_time` datetime DEFAULT NULL COMMENT '生成时间',
  `set_data` char(16) COMMENT '设定数据',
  `spec` char(128) COMMENT '说明',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 COMMENT='机器表' AUTO_INCREMENT=1 ;

--
-- 表的结构 `tb_company`
--
DROP TABLE IF EXISTS `tb_company`;
CREATE TABLE IF NOT EXISTS `tb_company` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '唯一id',
  `login_id` char(32) DEFAULT NULL COMMENT '登陆id',
  `name` char(32) COMMENT '名称',
  `manager_id` char(32) DEFAULT NULL COMMENT '公司管理者登录id',
  `tel` char(16) DEFAULT NULL COMMENT '电话',
  `city` char(16) DEFAULT NULL COMMENT '城市',
  `address` char(128) DEFAULT NULL COMMENT '地址',
  `create_t` datetime DEFAULT NULL COMMENT '生成时间',
  `spec` char(128) COMMENT '说明',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 COMMENT='公司' AUTO_INCREMENT=1 ;

--
-- 表的结构 `tb_store`
--
DROP TABLE IF EXISTS `tb_store`;
CREATE TABLE IF NOT EXISTS `tb_store` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '唯一id',
  `login_id` char(32) DEFAULT NULL COMMENT '登陆id',
  `name` char(32) COMMENT '名称',
  `manager_id` char(32) DEFAULT NULL COMMENT '店长id',
  `company_id` int(10) DEFAULT NULL COMMENT '从属公司',
  `tel` char(16) DEFAULT NULL COMMENT '电话',
  `city` char(16) DEFAULT NULL COMMENT '城市',
  `address` char(128) DEFAULT NULL COMMENT '地址',
  `create_t` datetime DEFAULT NULL COMMENT '生成时间',
  `spec` char(128) COMMENT '说明',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 COMMENT='店家' AUTO_INCREMENT=1 ;

-- Table structure for table `tb_player`
DROP TABLE IF EXISTS `tb_player`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_player` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '自增id',
  `login_id` char(32) DEFAULT NULL COMMENT '登陆名',
  `password` char(32) DEFAULT NULL COMMENT '密码',
  `salt` char(32) DEFAULT NULL COMMENT '盐',
  `nickname` char(32) DEFAULT NULL COMMENT '昵称',
  `sex` char DEFAULT NULL COMMENT '性别',
  `age` smallint(5) DEFAULT NULL COMMENT '年龄',
  `tel` char(16) DEFAULT NULL COMMENT '电话',
  `money` int(10) DEFAULT NULL COMMENT '余额', 
  `create_t` datetime DEFAULT NULL COMMENT '生成时间',
  `reserved_data` char(16) DEFAULT NULL COMMENT '备用值',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;

--
-- 表的结构 `tb_incharge`
--
DROP TABLE IF EXISTS `tb_incharge`;
CREATE TABLE IF NOT EXISTS `tb_incharge` (
  `id` bigint(16) unsigned NOT NULL AUTO_INCREMENT,
  `player_login_id` char(32) NOT NULL, 
  `incharges_id` char(32) NOT NULL,
  `game_id` int(10) unsigned NOT NULL,
  `mach_id` int(10) unsigned NOT NULL,
  `play_no` smallint(5) NOT NULL COMMENT '卡位',
  `fee_type` smallint(5) NOT NULL COMMENT '货币类型',     
  `total_fee` decimal(10,2) unsigned NOT NULL COMMENT '充值金额',
  `is_incharged` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '是否兑换成功',
  `incharge_t` datetime DEFAULT NULL COMMENT '兑换时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;

DROP TABLE IF EXISTS `tb_record`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_record` (
  `id` bigint(16) NOT NULL AUTO_INCREMENT COMMENT '自增id',
  `player_login_id` char(32) DEFAULT NULL COMMENT '登陆名',
  `game_id` int(10) unsigned NOT NULL,
  `mach_id` int(10) unsigned NOT NULL,
  `play_no` smallint(5) NOT NULL COMMENT '卡位',
  `kind_id` smallint(5) DEFAULT NULL COMMENT '类型',
  `value` int(10) DEFAULT NULL COMMENT '值',
  `create_t` datetime DEFAULT NULL COMMENT '生成时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `tb_record_kind`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_record_kind` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '自增id',
  `name` char(16) DEFAULT NULL COMMENT '名称',
  `spec` char(128) COMMENT '说明',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `tb_room_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_room_info` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '自增id',
  `name` char(16) DEFAULT NULL COMMENT '名称',
  `create_t` datetime DEFAULT NULL COMMENT '生成时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
