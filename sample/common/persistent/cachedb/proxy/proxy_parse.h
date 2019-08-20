#ifndef __PROXY_PARSE_H 
#define __PROXY_PARSE_H
#include "glib.h"

typedef enum 
{
    int_type = 0,
    date_type,  //日期类型
}DIVI_TYPE;

typedef struct
{
	char divi_key[33];
	int divi_base;
    DIVI_TYPE divi_type;
}db_table_t;

typedef struct
{
    gint db_index;
    gint tb_index;
    gint alias;
}table_index;

typedef struct 
{
    GString* db_name;
    GString* tb_name;             
    GString* alias;
}table_name;

table_name *table_name_new();

void table_name_free(table_name *tb_cf);

// 解析库名和表名(第一张表index 和 join表的名字)
guint get_table_index(GPtrArray* tokens, const gchar* default_db, table_index *first_tb, GPtrArray* join_tbs);

// 解析库名和表名
guint get_first_table_index(GPtrArray* tokens, table_index *table);
// 解析右表库名和表名
guint get_right_table(GPtrArray* tokens, guint cur_table, table_index *table);
// dbname.tbname
table_name* get_table_name(GPtrArray *tokens, const gchar* default_db, table_index *tb);

// 解析列
GArray* get_column_index(GPtrArray* tokens, gchar* column_name, guint sql_type, gint alias_id, gint start) ;

// 拼接SQL,int 类型
int combine_int_sql(GPtrArray* tokens, gint table, GArray* columns, guint num, GPtrArray* sqls) ;

// 拼接SQL,date 类型, base_type 0 表示按day分表
int combine_date_sql(GPtrArray* tokens, gint table, GArray* columns, guint base_type, GPtrArray* sqls) ;

// SQL最终返回
int union_array_sql(GPtrArray* sqls, GString*un_sql);

// 判断是否是连接查询
int select_join_sql(GPtrArray *tokens);

#endif
