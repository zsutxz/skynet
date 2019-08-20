extern "C" {
#include "glib.h"
#include "sql-tokenizer.h"
#include "proxy_parse.h"
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}
#include "stdio.h"
#include "stdlib.h"
#include "string.h"
#include <string>
#include <map>

//gcc -I ./ -I /usr/local/include/glib-2.0/ -I /usr/local/lib/glib-2.0/include/  sql_split.c  sql-tokenizer.c glib-ext.c glib-ext-ref.c  sql-tokenizer-tokens.c sql-tokenizer-keywords.c  -l glib-2.0 -L /usr/share/ -std=c99 -shared -fPIC -o sql_split.so proxy_parse.c -Wall -O2


typedef std::map< std::string , db_table_t> DB_TABLE_MAP;
DB_TABLE_MAP G_divide_conf;

int load_divide_conf(lua_State *L)
{
    int index = lua_gettop(L);
    lua_pushnil(L);
    //table 判断
    if(lua_istable(L,-2) == 0)
    {   
        lua_pushstring(L,"load_divide_conf,args should be table");
        lua_error(L);
        return 0;
    }
    //清理global divide conf
    G_divide_conf.clear();

    const char* db_name;
    const char* tb_name;
    size_t str_len;

    db_table_t tb_conf; 

    //while循环遍历database 层
    while(lua_next(L,index))
    {
        db_name = lua_tolstring(L,-2,&str_len);
        //printf("while index:%d,-2:%s\n", index,db_name);
        //db层是table
        if(lua_istable(L,-1))
        {
            int db_index = lua_gettop(L);
            lua_pushnil(L);
            //printf("    dbindex:%d\n",db_index);

            //while循环遍历table层
            while(lua_next(L,db_index)){
                tb_name = lua_tolstring(L,-2,&str_len);

                //tb层配置
                if(lua_istable(L,-1))
                {
                    int tb_index = lua_gettop(L);
                    lua_pushnil(L);


                    //构造数据库表名字:db_name.tb_name
                    gchar* table_name = g_strdup_printf("%s.%s", db_name, tb_name);
                    std::string table_key(table_name);
                    g_free(table_name);
                    //printf("        tbindex:%d, 表名:%s\n",tb_index,table_key.c_str());

                    //遍历table配置
                    memset(&tb_conf,0,sizeof(db_table_t));
                    while(lua_next(L,tb_index))
                    {
                        const char* tb_key = lua_tostring(L,-2);
                        const char* tb_value = lua_tostring(L,-1);
                        //printf("            key:%s,val:%s\n",tb_key,tb_value);
                        if(strcasecmp(tb_key,"divi_key") == 0 )
                        {
                            //printf("            =divi_key=:%s\n",tb_value);
                            strncpy(tb_conf.divi_key, tb_value, sizeof(tb_conf.divi_key)-1);
                        }else if(strcasecmp(tb_key,"divi_base") == 0){
                            tb_conf.divi_base = atol(tb_value);
                            //printf("            =divi_base=:%s,atol:%d\n",tb_value,tb_conf.divi_base);
                        }else if (strcasecmp(tb_key,"divi_type") == 0){
                            tb_conf.divi_type = (DIVI_TYPE)atol(tb_value);
                            //printf("            =divi_type=:%s,atol:%d\n",tb_value,tb_conf.divi_type);
                        }

                        lua_pop(L,1);
                    }

                    //insert G_divie_conf
                    G_divide_conf.insert(DB_TABLE_MAP::value_type(table_key,tb_conf));
                }

                lua_pop(L,1);
            }
        }
        lua_pop(L,1);
    }

    return 0;
}

int travel_divide_conf(lua_State *L)
{
    printf("\n\n\n遍历global G_divide_conf\n");

    DB_TABLE_MAP::iterator itr = G_divide_conf.begin();
    for(;itr!=G_divide_conf.end();++itr)
    {
        printf("tablename:%s \n",itr->first.c_str());
        printf("    divi_key:%s,divi_base:%d,divi_type:%d\n",itr->second.divi_key,itr->second.divi_base,itr->second.divi_type);
    }

    return 0;
}

db_table_t *get_table_config(gchar *table_name)
{
    db_table_t *tb_conf = NULL;

    DB_TABLE_MAP::iterator itr = G_divide_conf.find(table_name);
    if(itr != G_divide_conf.end())
    {
        tb_conf = &(itr->second);
    }

    return tb_conf;
}

/*
int sql_parse(const gchar *default_db, GPtrArray* tokens, GString *out_put) {
	//1. 解析库名和表名
	gint db, table, alias;
	guint sql_type = get_table_index(tokens, &db, &table, &alias);
	if (table == -1) {
        g_string_append(out_put,"sql_parse err,get_table_index fail");
		return -1;
    }

	//2. 解析列
	gchar* table_name = NULL;
	if (db == -1) {
		table_name = g_strdup_printf("%s.%s", default_db, ((sql_token*)tokens->pdata[table])->text->str);
	} else {
		table_name = g_strdup_printf("%s.%s", ((sql_token*)tokens->pdata[db])->text->str, ((sql_token*)tokens->pdata[table])->text->str);
	}

    //分表配置
	db_table_t* dt = get_table_config(table_name);
	if (dt == NULL) {
        g_string_append_printf(out_put,"sql_parse err,get_table_config fail:%s",table_name);
		return -1;
	}
    g_free(table_name);

	GArray* columns = get_column_index(tokens, dt->divi_key, sql_type, alias, table+1);
	if (columns->len == 0) {
        g_string_append(out_put,"sql_parse err,get_column_index fail");
        return -1;
	}

	//3. 拼接SQL
	GPtrArray* sqls = g_ptr_array_new();
    switch(dt->divi_type)
    {
        case int_type:
            {
                combine_int_sql(tokens, table, columns, dt->divi_base, sqls);
                break;
            }
        case date_type:
            {
                combine_date_sql(tokens, table, columns, dt->divi_base, sqls);
                break;
            }
        default:
            {
                g_string_append_printf(out_put,"divi_type error ,unknowed type:%d\n",dt->divi_type);
                break;
            }
    }

    if(sqls->len != 0)
    {
        union_array_sql(sqls, out_put);

        for (guint i = 0; i < sqls->len; ++i) {
            GString *pstr = (GString*)(sqls->pdata[i]);
            g_string_free(pstr,TRUE);
        }
        g_ptr_array_free(sqls, TRUE);
    }

    g_array_free(columns, TRUE);
	return 0;
}
*/

int sql_join_parse(const gchar *default_db, GPtrArray* tokens, GString *out_put) {
	//1. 解析库名和表名
    GPtrArray *right_tbs = g_ptr_array_new();
    table_index *first_tb = g_new0(table_index, 1);
	guint sql_type = get_table_index(tokens, default_db, first_tb, right_tbs);


    //2. 处理left table
	gchar* tb_name= NULL;
	if (first_tb->db_index== -1) {
		tb_name = g_strdup_printf("%s.%s", default_db, ((sql_token*)tokens->pdata[first_tb->tb_index])->text->str);
	} else {
		tb_name = g_strdup_printf("%s.%s", ((sql_token*)tokens->pdata[first_tb->db_index])->text->str, ((sql_token*)tokens->pdata[first_tb->tb_index])->text->str);
	}

    //2.1 分表配置
	db_table_t* divi_cf = get_table_config(tb_name);
	if (divi_cf == NULL) {
        g_string_append_printf(out_put,"sql_parse err,first table 获取分表配置失败:%s",tb_name);
		return -1;
	}
    g_free(tb_name);

    //2.2 分表column
	GArray* columns = get_column_index(tokens, divi_cf->divi_key, sql_type, first_tb->alias, first_tb->tb_index+1);
	if (columns->len == 0) {
        g_string_append_printf(out_put,"sql_parse err,first table 定位分表key column失败:%s",divi_cf->divi_key);
        return -1;
	}

	//2.3 拼接SQL
	GPtrArray* sqls = g_ptr_array_new();
    switch(divi_cf->divi_type)
    {
        case int_type:
            {
                combine_int_sql(tokens, first_tb->tb_index, columns, divi_cf->divi_base, sqls);
                break;
            }
        case date_type:
            {
                combine_date_sql(tokens, first_tb->tb_index, columns, divi_cf->divi_base, sqls);
                break;
            }
        default:
            {
                g_string_append_printf(out_put,"divi_type error ,unknowed type:%d\n",divi_cf->divi_type);
                break;
            }
    }
    g_array_free(columns, TRUE);

    //非select join 查询
    if(right_tbs->len == 0)
    {
        if(sqls->len != 0)
        {
            union_array_sql(sqls, out_put);

            for (guint i = 0; i < sqls->len; ++i) {
                GString *pstr = (GString*)(sqls->pdata[i]);
                g_string_free(pstr,TRUE);
            }
            g_ptr_array_free(sqls, TRUE);
        }

        g_free(first_tb);
        g_ptr_array_free(right_tbs,TRUE);
        return 0;
    }

    //right table
	table_name** ts = (table_name**)(right_tbs->pdata);
    guint ts_len = right_tbs->len;

    for(guint i=0;i<ts_len;++i)
    {
        //printf("for :%d\n",i);
        //由于table_name_%d , 需要 table_index ,但后续的table位置改变了，需要名字
        //第二种做法,get index, 再get 所有 table_config
        //printf("db_name:%s ,tb_name:%s \n", ts[i]->db_name->str, ts[i]->tb_name->str);
        if(ts[i]->alias != NULL)
        {
            //printf("\talisa:%s\n",ts[i]->alias->str);
        }

        table_name_free(ts[i]);
    }

    if(sqls->len != 0)
    {
        //暂时
        union_array_sql(sqls, out_put);

        for (guint i = 0; i < sqls->len; ++i) {
            GString *pstr = (GString*)(sqls->pdata[i]);
            g_string_free(pstr,TRUE);
        }
        g_ptr_array_free(sqls, TRUE);
    }
    g_free(first_tb);
    g_ptr_array_free(right_tbs,TRUE);

	return 0;
}

int sql_split(lua_State *L)
{
    size_t len = 0;
	const char* default_db = lua_tostring(L,1);
	const char* src = lua_tolstring(L,2,&len);
    if(src == NULL)
    {
        lua_pushinteger(L,-1);
        lua_pushstring(L,"sql_split error ,sql string is null!");
        return 2;
    }

	GPtrArray *tokens = sql_tokens_new();
	int ret = sql_tokenizer(tokens, src, len);
    if(ret != 0)
    {
        lua_pushinteger(L,-1);
        lua_pushstring(L,"sql_split error ,sql tokenizer fail!");

        sql_tokens_free(tokens);
        return 2;
    }

    //printf every token
    /*
    sql_token **ts = (sql_token**)tokens->pdata;
    guint t_len = tokens->len,i=0;
    for(;i<t_len;++i)
    {
        printf("i:%d,token_id:%d, %s\n",i,ts[i]->token_id, ts[i]->text->str);
    }
    */

    GString* out_put = g_string_new("");
    int parse = -1;

    parse = sql_join_parse(default_db, tokens, out_put);

    lua_pushinteger(L,parse);
    lua_pushlstring(L,out_put->str,out_put->len);
    g_string_free(out_put, TRUE);

    sql_tokens_free(tokens);
    return 2;
}

//创建部分
extern "C" int luaopen_libsql_split(lua_State *L)
{
    static const struct luaL_Reg l[] = {
        { "load_divide_conf", load_divide_conf },
        { "travel_divide_conf", travel_divide_conf },
        { "sql_csplit", sql_split },
        { NULL, NULL}
    };
	luaL_newlib(L,l);
	return 1;
}

// TK_ 
/*
 * TK_LITERAL 9  变量名 accounts useid 
 * TK_COMMENT 8  注释
 * TK_DOT     13 .
 * TK_SEMICOLON 18  分号;
 */

