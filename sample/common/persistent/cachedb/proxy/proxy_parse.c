#define _XOPEN_SOURCE
#include "proxy_parse.h"
#include "sql-tokenizer.h"
#include "stdlib.h"
#include "time.h"
#include "strings.h"
#include "string.h"
#include "glib.h"

#include "stdio.h"

table_name *table_name_new()
{
    table_name *tb_cf = g_new0(table_name, 1);
}

void table_name_free(table_name *tb_cf)
{
    if(!tb_cf) return;

    if(tb_cf->db_name != NULL)
        g_string_free(tb_cf->db_name, TRUE);
    if(tb_cf->tb_name != NULL)
        g_string_free(tb_cf->tb_name, TRUE);
    if(tb_cf->alias!= NULL)
        g_string_free(tb_cf->alias, TRUE);

    g_free(tb_cf);
}


// 解析库名和表名
guint get_table_index(GPtrArray* tokens, const gchar* default_db, table_index *first_tb, GPtrArray* join_tbs)
{
    //get first table 的index
    guint sql_type = get_first_table_index(tokens, first_tb);

    //非select,delete 不处理join表
    if(sql_type != 1)
        return sql_type;

    //select or delete
    guint cur_tb = first_tb->tb_index;

    table_index *right_tb = g_new0(table_index,1);
    while(TRUE)
    {
        guint right_type = get_right_table(tokens, cur_tb, right_tb);
        if(right_type == 0)
        {
            //没有更多的数据了
            break;
        }else{
            //get table config
            table_name* right_cf = get_table_name(tokens, default_db, right_tb);

            g_ptr_array_add(join_tbs, right_cf);
            cur_tb = right_tb->tb_index;
        }
    }
    g_free(right_tb);

    return sql_type;
}

guint get_first_table_index(GPtrArray* tokens, table_index *table) {
    table->db_index = table->tb_index = table->alias = -1;

    sql_token** ts = (sql_token**)(tokens->pdata);
    guint len = tokens->len;

    guint i = 0, j;
    while (ts[i]->token_id == TK_COMMENT && ++i < len);
    sql_token_id token_id = ts[i]->token_id;

    if (token_id == TK_SQL_SELECT || token_id == TK_SQL_DELETE) {
        for (; i < len; ++i) {
            if (ts[i]->token_id == TK_SQL_FROM) {
                for (j = i+1; j < len; ++j) {
                    if (ts[j]->token_id == TK_SQL_WHERE) break;

                    if (ts[j]->token_id == TK_LITERAL) {
                        if (j + 2 < len && ts[j+1]->token_id == TK_DOT) {
                            table->db_index = j;
                            table->tb_index = j + 2;
                        } else {
                            table->tb_index = j;
                        }
                        break;
                    }
                }
                break;
            }
        }

        //alias
        if (table->tb_index != -1 && ts[table->tb_index+1]->token_id == TK_SQL_AS && ts[table->tb_index+2]->token_id == TK_LITERAL ){
            table->alias = table->tb_index + 2;
        }else if(table->tb_index != -1 && ts[table->tb_index+1]->token_id == TK_LITERAL){
            table->alias = table->tb_index + 1;
        }
        return 1;
    } else if (token_id == TK_SQL_UPDATE) {
        for (; i < len; ++i) {
            if (ts[i]->token_id == TK_SQL_SET) break;

            if (ts[i]->token_id == TK_LITERAL) {
                if (i + 2 < len && ts[i+1]->token_id == TK_DOT) {
                    table->db_index = i;
                    table->tb_index = i + 2;
                } else {
                    table->tb_index = i;
                }
                break;
            }
        }

        //alias
        if (table->tb_index != -1 && ts[table->tb_index+1]->token_id == TK_SQL_AS && ts[table->tb_index+2]->token_id == TK_LITERAL ){
            table->alias = table->tb_index + 2;
        }else if(table->tb_index != -1 && ts[table->tb_index+1]->token_id == TK_LITERAL){
            table->alias = table->tb_index + 1;
        }

        return 2;
    } else if (token_id == TK_SQL_INSERT || token_id == TK_SQL_REPLACE) {
        if(ts[i+1]->token_id == TK_SQL_INTO)
        {
            for (; i < len; ++i) {
                gchar* str = ts[i]->text->str;
                if (strcasecmp(str, "VALUES") == 0 || strcasecmp(str, "VALUE") == 0) break;

                if (ts[i]->token_id == TK_LITERAL) {
                    if(i + 2 < len && ts[i+1]->token_id == TK_DOT) {
                        table->db_index = i;
                        table->tb_index = i + 2;
                    } else {
                        table->tb_index = i;
                    }
                    break;
                }
            }
        }

        //alias
        if (table->tb_index != -1 && ts[table->tb_index+1]->token_id == TK_SQL_AS && ts[table->tb_index+2]->token_id == TK_LITERAL ){
            table->alias = table->tb_index + 2;
        }else if(table->tb_index != -1 && ts[table->tb_index+1]->token_id == TK_LITERAL){
            table->alias = table->tb_index + 1;
        }
        return 3;
	}

	return 0;
}

guint get_right_table(GPtrArray* tokens, guint cur_table, table_index *table) {
    table->db_index = table->tb_index = table->alias = -1;

    sql_token** ts = (sql_token**)(tokens->pdata);
    guint len = tokens->len;

    guint i = cur_table + 1, j;

    for (; i < len; ++i) {
        if (ts[i]->token_id == TK_SQL_JOIN) {
            j = i + 1;
            if (ts[j]->token_id == TK_SQL_ON) break;

            if (ts[j]->token_id == TK_LITERAL) {
                if (j + 2 < len && ts[j+1]->token_id == TK_DOT) {
                    table->db_index = j;
                    table->tb_index = j + 2;
                } else {
                    table->tb_index = j;
                }
                break;
            }
        }
    }

    if (table->tb_index == -1)
        return 0;

    //alias
    if (table->tb_index != -1 && ts[table->tb_index+1]->token_id == TK_SQL_AS && ts[table->tb_index+2]->token_id == TK_LITERAL ){
        table->alias = table->tb_index + 2;
    }else if(table->tb_index != -1 && ts[table->tb_index+1]->token_id == TK_LITERAL){
        table->alias = table->tb_index + 1;
    }
    return 1;
}

table_name* get_table_name(GPtrArray *tokens, const gchar* default_db, table_index *tb)
{
    sql_token **ts = (sql_token**)tokens->pdata;
    table_name *tb_cf = table_name_new();

	if (tb->db_index == -1) {
        tb_cf->db_name = g_string_new(default_db);
	} else {
        tb_cf->db_name = g_string_new(ts[tb->db_index]->text->str);
	}
    tb_cf->tb_name = g_string_new(ts[tb->tb_index]->text->str);

    //alias
    if (tb->alias != -1)
        tb_cf->alias = g_string_new(ts[tb->alias]->text->str);

    return tb_cf;
}

GArray* get_column_index(GPtrArray* tokens, gchar* column_name, guint sql_type, gint alias_id, gint start) {
	GArray* columns = g_array_new(FALSE, FALSE, sizeof(guint));

	sql_token** ts = (sql_token**)(tokens->pdata);
	guint len = tokens->len;
	guint i, j, k;
    
    gchar *alias = NULL;
    if(alias_id != -1)
    {
        alias = ts[alias_id]->text->str;
        start = alias_id + 1;
    }

	if (sql_type == 1) {
		for (i = start; i < len; ++i) {
			if (ts[i]->token_id == TK_SQL_WHERE || ts[i]->token_id == TK_SQL_ON ) {
				for (j = i+1; j < len-2; ++j) {
					if (ts[j]->token_id == TK_LITERAL && strcasecmp(ts[j]->text->str, column_name) == 0) {
                        //integer or string
						if (ts[j+1]->token_id == TK_EQ && (ts[j+2]->token_id == TK_INTEGER || ts[j+2]->token_id == TK_STRING) ) {
                            if (ts[j-1]->token_id != TK_DOT || (alias_id != -1 && strcasecmp(ts[j-2]->text->str, alias) == 0) ){
								k = j + 2;
								g_array_append_val(columns, k);
								break;
							}
						} else if (j + 3 < len && strcasecmp(ts[j+1]->text->str, "IN") == 0 && ts[j+2]->token_id == TK_OBRACE) {
                            if (ts[j-1]->token_id != TK_DOT || (alias_id != -1 && strcasecmp(ts[j-2]->text->str, alias) == 0) ){
                                k = j + 3;
                                g_array_append_val(columns, k);
                                while ((k += 2) < len && ts[k-1]->token_id != TK_CBRACE) {
                                    g_array_append_val(columns, k);
                                }
                                break;
                            }
						}
					}
				}
				break;
			}
		}
	} else if (sql_type == 2) {
		for (i = start; i < len; ++i) {
			if (ts[i]->token_id == TK_SQL_WHERE) {
				for (j = i+1; j < len-2; ++j) {
					if (ts[j]->token_id == TK_LITERAL && strcasecmp(ts[j]->text->str, column_name) == 0) {
                        //integer or string
						if (ts[j+1]->token_id == TK_EQ && (ts[j+2]->token_id == TK_INTEGER || ts[j+2]->token_id == TK_STRING) ) {
                            if (ts[j-1]->token_id != TK_DOT || (alias_id != -1 && strcasecmp(ts[j-2]->text->str, alias) == 0) ){
								k = j + 2;
								g_array_append_val(columns, k);
								break;
							}
						} else if (j + 3 < len && strcasecmp(ts[j+1]->text->str, "IN") == 0 && ts[j+2]->token_id == TK_OBRACE) {
                            if (ts[j-1]->token_id != TK_DOT || (alias_id != -1 && strcasecmp(ts[j-2]->text->str, alias) == 0) ){
                                k = j + 3;
                                g_array_append_val(columns, k);
                                while ((k += 2) < len && ts[k-1]->token_id != TK_CBRACE) {
                                    g_array_append_val(columns, k);
                                }
                                break;
                            }
						}
					}
				}
				break;
			}
		}
	} else if (sql_type == 3) {
		sql_token_id token_id = ts[start]->token_id;

		if (token_id == TK_SQL_SET) {
			for (i = start+1; i < len-2; ++i) {
				if (ts[i]->token_id == TK_LITERAL && strcasecmp(ts[i]->text->str, column_name) == 0) {
                    // 别名判断
                    if (ts[i-1]->token_id != TK_DOT || (alias_id != -1 && strcasecmp(ts[i-2]->text->str, alias) == 0) ){
                        // "=" 和 值判断
						if (ts[i+1]->token_id == TK_EQ && (ts[i+2]->token_id == TK_INTEGER || ts[i+2]->token_id == TK_STRING) ) {
                            k = i + 2;
                            g_array_append_val(columns, k);
                            break;
                        }
                    }
				}
			}
		} else {
            guint comma = -1, found = -1;
			if (token_id == TK_OBRACE) {
				for (j = start+1; j < len; ++j) {
					token_id = ts[j]->token_id;
					if (token_id == TK_CBRACE) break;

					if (token_id == TK_LITERAL && strcasecmp(ts[j]->text->str, column_name) == 0) {
                        if (ts[j-1]->token_id != TK_DOT || (alias_id != -1 && strcasecmp(ts[j-2]->text->str, alias) == 0) ){
                            found = j;
                            break;
                        }
					}
				}
                if(found != -1){
                    comma=0;
                    guint cm=start+1;
                    //多少个',':comma
                    for(;cm<found;++cm)
                    {
                        if(ts[cm]->token_id == TK_COMMA)
                            ++comma;
                    }
                }
			}

            if(found != -1) {
                guint obrace = -1;
                for (i = found; i < len-1; ++i) {
                    gchar* str = ts[i]->text->str;
                    if ((strcasecmp(str, "VALUES") == 0 || strcasecmp(str, "VALUE") == 0) && ts[i+1]->token_id == TK_OBRACE) {
                        obrace = i+1;
                        break;
                    }
                }
                if(obrace != -1)
                {
                    for(k=obrace+1;k<len-1;++k)
                    {
                        if(comma == 0)
                        {
                            //校验column

                            break;
                        }

                        if(ts[k]->token_id == TK_COMMA)
                            --comma;
                    }
                    //插入columns
                    if (k < len) g_array_append_val(columns, k);
                }
            }//if found != 1
		}
	}
	return columns;
}

int combine_int_sql(GPtrArray* tokens, gint table, GArray* columns, guint num,GPtrArray* sqls) {
	sql_token** ts = (sql_token**)(tokens->pdata);
	guint len = tokens->len;
	guint i;

	if (columns->len == 1) {
		GString* sql = g_string_new("");

		if (ts[0]->token_id == TK_COMMENT) {
			g_string_append_printf(sql, "/*%s*/", ts[0]->text->str);
		} else {
			g_string_append(sql, ts[0]->text->str);
		}

		for (i = 1; i < len; ++i) {
			sql_token_id token_id = ts[i]->token_id;

			if (token_id != TK_OBRACE) g_string_append_c(sql, ' '); 

			if (i == table) {
				g_string_append_printf(sql, "%s_%u", ts[i]->text->str, atoi(ts[g_array_index(columns, guint, 0)]->text->str) / num);
			} else if (token_id == TK_STRING) {
				g_string_append_printf(sql, "'%s'", ts[i]->text->str);
			} else if (token_id == TK_COMMENT) {
				g_string_append_printf(sql, "/*%s*/", ts[i]->text->str);
            } else if (token_id == TK_LITERAL) {
                g_string_append_printf(sql, "`%s`", ts[i]->text->str);
			} else {
				g_string_append(sql, ts[i]->text->str);
			}
		}

		g_ptr_array_add(sqls, sql);
	} else {
        const guint max_divide_num = 128;
		GArray* mt[max_divide_num];
        memset(mt,0,sizeof(mt));
		//for (i = 0; i < max_divide_num; ++i) mt[i] = NULL;//g_array_new(FALSE, FALSE, sizeof(guint));

		guint clen = columns->len;
		for (i = 0; i < clen; ++i) {
			guint column_value = atoi(ts[g_array_index(columns, guint, i)]->text->str);

            guint mt_index = column_value/num;
            if(mt_index >= max_divide_num) 
            {
                printf("combine sql error ,分表数大于最大分表限制max_divide_num:%d\n",max_divide_num);
                continue;
            }

            if(mt[mt_index] == NULL) mt[mt_index] = g_array_new(FALSE,FALSE,sizeof(guint));
			g_array_append_val(mt[mt_index], column_value);
		}

		guint property_index   = g_array_index(columns, guint, 0) - 3;
		guint start_skip_index = property_index + 1;
		guint end_skip_index   = property_index + (clen + 1) * 2;

		guint m;
		for (m = 0; m < max_divide_num; ++m) {
			if (mt[m] != NULL && mt[m]->len > 0) {
				GString* tmp = g_string_new(" IN(");
				g_string_append_printf(tmp, "%u", g_array_index(mt[m], guint, 0));
				guint k;
				for (k = 1; k < mt[m]->len; ++k) {
					g_string_append_printf(tmp, ",%u", g_array_index(mt[m], guint, k));
				}
				g_string_append_c(tmp, ')');

				GString* sql = g_string_new("");
				if (ts[0]->token_id == TK_COMMENT) {
					g_string_append_printf(sql, "/*%s*/", ts[0]->text->str);
				} else {
					g_string_append(sql, ts[0]->text->str);
				}
				for (i = 1; i < len; ++i) {
					if (i < start_skip_index || i > end_skip_index) {
						if (ts[i]->token_id != TK_OBRACE) g_string_append_c(sql, ' ');

						if (i == table) {
							g_string_append_printf(sql, "%s_%u", ts[i]->text->str, m);
						} else if (i == property_index) {
							g_string_append_printf(sql, "%s%s", ts[i]->text->str, tmp->str);
						} else if (ts[i]->token_id == TK_STRING) {
							g_string_append_printf(sql, "'%s'", ts[i]->text->str);
						} else if (ts[i]->token_id == TK_COMMENT) {
							g_string_append_printf(sql, "/*%s*/", ts[i]->text->str);
                        } else if (ts[i]->token_id == TK_LITERAL) {
                            g_string_append_printf(sql, "`%s`", ts[i]->text->str);
						} else {
                            //";" not append
                            if(ts[i]->token_id != TK_SEMICOLON)
                            {
                                g_string_append(sql, ts[i]->text->str);
                            }
						}
					}
				}
				g_string_free(tmp, TRUE);

				g_ptr_array_add(sqls, sql);
			}

            if(mt[m] != NULL) g_array_free(mt[m], TRUE);
		}
	}

	return sqls->len;
}

guint date_convert(GString *date_str,guint base_type)
{
    struct tm tm_time;
    memset(&tm_time ,0 ,sizeof(struct tm));
    char* what = strptime(date_str->str,"%Y-%m-%d", &tm_time);
    if(what == NULL)
        what = strptime(date_str->str,"%m/%d/%Y", &tm_time);
    if(what == NULL)
        what = strptime(date_str->str,"%Y%m%d", &tm_time);

    char timebuf[32]={};
    if(what != NULL)
    {
        switch(base_type)
        {
            case 0:
                strftime(timebuf,sizeof(timebuf),"%Y%m%d", &tm_time);
                break;
            case 1:
                strftime(timebuf,sizeof(timebuf),"%Y%m", &tm_time);
                break;
            case 2:
                strftime(timebuf,sizeof(timebuf),"%Y", &tm_time);
                break;
        }

    }

    guint time_suff = atoi(timebuf);
    return time_suff;
}

//直接返回当前时间
guint get_current_date()
{
    time_t rawtime;
    time(&rawtime);
    struct tm *tm_time = localtime(&rawtime);

    char timebuf[32]={};
    strftime(timebuf,sizeof(timebuf),"%Y%m%d", tm_time);

    guint time_suff = atoi(timebuf);
    return time_suff;
}

int combine_date_sql(GPtrArray* tokens, gint table, GArray* columns, guint base_type, GPtrArray* sqls) {
	sql_token** ts = (sql_token**)(tokens->pdata);
	guint len = tokens->len;
	guint i,j;

	if (columns->len == 1) {
		GString* sql = g_string_new("");

		if (ts[0]->token_id == TK_COMMENT) {
			g_string_append_printf(sql, "/*%s*/", ts[0]->text->str);
		} else {
			g_string_append(sql, ts[0]->text->str);
		}

		for (i = 1; i < len; ++i) {
			sql_token_id token_id = ts[i]->token_id;

			if (token_id != TK_OBRACE) g_string_append_c(sql, ' '); 

			if (i == table) {
                guint date_suff = date_convert(ts[g_array_index(columns,guint,0)]->text,base_type);
				g_string_append_printf(sql, "%s_%u ", ts[i]->text->str, date_suff);
			} else if (token_id == TK_STRING) {
				g_string_append_printf(sql, "'%s'", ts[i]->text->str);
			} else if (token_id == TK_COMMENT) {
				g_string_append_printf(sql, "/*%s*/", ts[i]->text->str);
			} else if (token_id == TK_LITERAL) {
				g_string_append_printf(sql, "`%s`", ts[i]->text->str);
			} else {
				g_string_append(sql, ts[i]->text->str);
			}
		}

		g_ptr_array_add(sqls, sql);
	} else {
		guint clen = columns->len;
        const guint max_sql_num = 32;
        if(clen >= max_sql_num)
        {
            printf("combine sql error ,分表数大于最大sqls限制max_sql_num:%d\n",max_sql_num);
            return sqls->len;
        }

		GPtrArray* mt[max_sql_num];                                 //每一后缀对应的
        guint dt[max_sql_num];                                      //存放table后缀的数组
        memset(mt,0,sizeof(mt));
        memset(dt,0,sizeof(dt));

        guint group_num = 0;                                        //共多少组数据
		for (i = 0; i < clen;++i) {
            GString *column_value = ts[g_array_index(columns, guint, i)]->text;
            guint i_index = date_convert(column_value,base_type);

            GPtrArray *group=NULL;
            for(j=0;j<group_num;++j)
            {
                if(dt[j] == i_index)
                    group = mt[j];
            }
            if(group == NULL)
            {
                group = g_ptr_array_new();
                mt[group_num] = group;
                dt[group_num] = i_index;
                group_num++;
            }
			g_ptr_array_add(group, column_value);
		}

        ////////////////////////////////
        /*
        printf("group_num:%d\n",group_num);
        for(i=0;i<group_num;++i)
        {
            printf("i:%u,suff:%u\n",i,dt[i]);
        
            for(j=0;j<mt[i]->len;++j)
            {
                GString *pstr = mt[i]->pdata[j];
                printf("    values:%s\n", pstr->str);
            }

        }
        */
        ////////////////////////////////

		guint property_index   = g_array_index(columns, guint, 0) - 3;
		guint start_skip_index = property_index + 1;
		guint end_skip_index   = property_index + (clen + 1) * 2;

		guint m;
        GString *p_column = NULL;
		for (m = 0; m < group_num; ++m) {
			if (mt[m] != NULL && mt[m]->len > 0) {
				GString* tmp = g_string_new(" IN(");
                p_column = mt[m]->pdata[0];
				g_string_append_printf(tmp, "'%s'", p_column->str);
				guint k;
				for (k = 1; k < mt[m]->len; ++k) {
                    p_column = mt[m]->pdata[k];
					g_string_append_printf(tmp, ",'%s'",p_column->str);
				}
				g_string_append_c(tmp, ')');

				GString* sql = g_string_new("");
				if (ts[0]->token_id == TK_COMMENT) {
					g_string_append_printf(sql, "/*%s*/", ts[0]->text->str);
				} else {
					g_string_append(sql, ts[0]->text->str);
				}
				for (i = 1; i < len; ++i) {
					if (i < start_skip_index || i > end_skip_index) {
						if (ts[i]->token_id != TK_OBRACE) g_string_append_c(sql, ' ');

						if (i == table) {
							g_string_append_printf(sql, "%s_%u", ts[i]->text->str, dt[m]);
						} else if (i == property_index) {
							g_string_append_printf(sql, "%s%s", ts[i]->text->str, tmp->str);
						} else if (ts[i]->token_id == TK_STRING) {
							g_string_append_printf(sql, "'%s'", ts[i]->text->str);
						} else if (ts[i]->token_id == TK_COMMENT) {
							g_string_append_printf(sql, "/*%s*/", ts[i]->text->str);
                        } else if (ts[i]->token_id == TK_LITERAL) {
                            g_string_append_printf(sql, "`%s`", ts[i]->text->str);
                        } else {
                            //";" not append
                            if(ts[i]->token_id != TK_SEMICOLON)
                            {
                                g_string_append(sql, ts[i]->text->str);
                            }
						}
					}
				}
				g_string_free(tmp, TRUE);

				g_ptr_array_add(sqls, sql);
			}

            if(mt[m] != NULL) g_ptr_array_free(mt[m], TRUE);
		}
	}

	return sqls->len;
    
}

int union_array_sql(GPtrArray* sqls, GString *un_sql){
    if(sqls->len > 1){
        for (guint i = 0; i < sqls->len; ++i) {
            GString *pstr = sqls->pdata[i];

            g_string_append_printf(un_sql,"%s",pstr->str);

            //union next sql
            if(i+1 != sqls->len)
            {
                g_string_append(un_sql,"union ");
            }
        }
        g_string_append(un_sql,";");
    }else{
        GString *pstr = sqls->pdata[0];
        g_string_append_len(un_sql,pstr->str,pstr->len);
    }

    return 0;
}

int select_join_sql(GPtrArray *tokens)
{
    sql_token** ts = (sql_token**)(tokens->pdata);
    guint len = tokens->len;

    guint i = 0, join_num = 0;
    while (ts[i]->token_id == TK_COMMENT && ++i < len);
    sql_token_id token_id = ts[i]->token_id;
    if (token_id == TK_SQL_SELECT) {
        for (; i < len; ++i) {
            if (ts[i]->token_id == TK_SQL_JOIN) {
                ++join_num;
            }
        }
    }
    return join_num;
}

