#include <sourcemod>
#include <shop>

#pragma newdecls required
#pragma tabsize 0

char g_questions[100][256];
char g_answers[100][256];
char g_credits[100][256];
char g_time[100][256];
int count;
int mincredits;
int maxcredits;
float minquestion;
float maxquestion;
float timeanswer;
int credits;
int questionCount;

ArrayList Answers;
Handle timerQuestionEnd;

public Plugin myinfo =
{
    name = "[SHOP] Quizz",
    author = "TTony, Arkarr / Psychologist21 & AlmazON",
    description = "Quizz System",
    version = "1.0",
    url = "https://github.com/PrdTTony"
};

public void OnPluginStart()
{   
	RegAdminCmd("sm_reloadquizz", Command_ReloadConfig, ADMFLAG_ROOT, "Reloads Quizz config file");
	ConVar cvar = CreateConVar("sm_Quizz_minimum_credits",	"5",	"The minimum number of credits earned for a correct answer.", _, true, 1.0)
	HookConVarChange(cvar, CVAR_MinimumCredits);
	mincredits = cvar.IntValue;
	HookConVarChange(cvar = CreateConVar("sm_Quizz_maximum_credits",	"100",	"The maximum number of credits earned for a correct answer.", _, true, 1.0), CVAR_MaximumCredits);
	maxcredits = cvar.IntValue;
	HookConVarChange(cvar = CreateConVar("sm_Quizz_time_guess_word",	"15",	"Time in seconds to guess the given word.", _, true, 5.0),	CVAR_TimeAnswer);
	timeanswer = cvar.FloatValue;
	HookConVarChange(cvar = CreateConVar("sm_Quizz_time_minamid_questions",	"100",	"The minimum time in seconds between each of the words.", _, true, 5.0),	CVAR_MinQuestion);
	minquestion = cvar.FloatValue;
	HookConVarChange(cvar = CreateConVar("sm_Quizz_time_maxamid_questions",	"250",	"The maximum time in seconds between each of the words.", _, true, 10.0),	CVAR_MaxQuestion);
	maxquestion = cvar.FloatValue;
	AutoExecConfig(true, "shop_Quizz");
	Answers = new ArrayList(ByteCountToCells(256));
    LoadConfig();
}

public void CVAR_MinimumCredits(ConVar convar, const char[] oldValue, const char[] newValue)
{
	mincredits = convar.IntValue;
}
public void CVAR_MaximumCredits(ConVar convar, const char[] oldValue, const char[] newValue)
{
	maxcredits = convar.IntValue;
}
public void CVAR_TimeAnswer(ConVar convar, const char[] oldValue, const char[] newValue)
{
	timeanswer = convar.FloatValue;
}
public void CVAR_MinQuestion(ConVar convar, const char[] oldValue, const char[] newValue)
{
	minquestion = convar.FloatValue;
}
public void CVAR_MaxQuestion(ConVar convar, const char[] oldValue, const char[] newValue)
{
	maxquestion = convar.FloatValue;
}

public void OnConfigsExecuted()
{   
	timerQuestionEnd = null;
	CreateTimer(GetRandomFloat(minquestion, maxquestion), CreateQuestion, _, TIMER_FLAG_NO_MAPCHANGE);		// Once the config gets executed we start the sending questions timer 
}

public Action CreateQuestion(Handle timer)
{   
	char sBuffer[100][256];

    Answers.Clear();  								// Clearing the ArrayList to hold the answers				 

	if(questionCount >= count){						// If there are no more new questions left we reset the counting
		questionCount = 0;
	}

    int c = ExplodeString(g_answers[questionCount], ";", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));			// Getting all the answers for the chosen question

    for(int i = 0; i <= c - 1; i++)
    {   
        Answers.PushString(sBuffer[i]);				// Pushing all the questions into the ArrayList
    }

	int credits_config = StringToInt(g_credits[questionCount]);
	if(credits_config > 0)
	{
		credits = credits_config;								// Getting the number of credits for the question set in config file 
	} else {
		credits = GetRandomInt(mincredits, maxcredits);			// Getting a random number of credits between mix and max convars
	}

	int newtime;
	float time = StringToFloat(g_time[questionCount]);
	if(time != '\0' && time > 0)																// If theres a time in the config we'll use it 
	{
		timerQuestionEnd = CreateTimer(time, EndQuestion, _, TIMER_FLAG_NO_MAPCHANGE);			// Starting the timer to answer the question
		newtime = StringToInt(g_time[questionCount]);
	} else {																					// If there isnt we'll use the default set in the convars
		timerQuestionEnd = CreateTimer(timeanswer, EndQuestion, _, TIMER_FLAG_NO_MAPCHANGE);	// Starting the timer to answer the question
		newtime = RoundFloat(timeanswer);
	}

	PrintToChatAll(" \x02----------------------------------");
    PrintToChatAll(" \x02[Shop] \x01Question: %s", g_questions[questionCount]);					// Printing the question in the server chat
    PrintToChatAll(" \x02[Shop] \x01Prize: %i credits", credits);
	PrintToChatAll(" \x02[Shop] \x01Time: %i seconds", newtime);
	PrintToChatAll(" \x02----------------------------------");
	questionCount++;											// Moving to the next question in the config 
    return Plugin_Stop;
}

public Action EndQuestion(Handle timer)
{   
	SendEndQuestion();						// After the answering time has past we send the final answer
	return Plugin_Stop;
}

void SendEndQuestion(int client = 0)
{
	int i = MaxClients;		// Getting all players
	if(client)				// Checking if a player is the winner
	{
		while(i)			// Sending a message to everyone
		{
			if(IsClientInGame(i)){
				PrintToChat(i, " \x02----------------------------------");
				PrintToChat(i, " \x02[Shop] \x10%N \x01won \x04%i \x01credits for answering correct", client, credits);
				PrintToChat(i, " \x02----------------------------------");
			} 
			--i;
		}
		delete timerQuestionEnd;
	}
	else					// If theres no winner we send another message
	{
		while(i)
		{
			if(IsClientInGame(i)) PrintToChat(i, " \x02[Shop] \x01Time expired. No correct answer :(");		// Sending the message to everyone
			--i;
		}
	}
	OnConfigsExecuted();		// Starting over 
}


public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{   
	if(timerQuestionEnd && Answers.FindString(sArgs) != -1)		// Checking if the answer timer is on and if the answer is good 
	{   
		int clients[1];
		Shop_GiveClientCredits(clients[0] = client, credits);								//Giving the winner credits
		PrintHintText(clients[0], "You won %i credits for answering correct", credits);								
		SendEndQuestion(clients[0]);							// Sending the final message	
	}
}

void LoadConfig()
{
    KeyValues kv = new KeyValues("Quizz");
    if (FileToKeyValues(kv, "addons/sourcemod/configs/Shop_Quizz.cfg"))		// Finding the config 
    {   
        count = 0;		// Initializing the counter

        if(kv.JumpToKey("Questions"))		// Jumping to questions in the config
        {
            if(kv.GotoFirstSubKey()){		// Going to the first question

                count = 0;
                do
                {
                    kv.GetString("question", g_questions[count], 256);		// Getting the question
                    kv.GetString("answers", g_answers[count], 256);			// Getting the answer
					kv.GetString("credits", g_credits[count], 256);			// Getting the credits
					kv.GetString("time", g_time[count], 256);			// Getting the time 
                    count++;
                    
                } while (kv.GotoNextKey());		// Moving to the next question
            }
            kv.Rewind();		// Going all the way back in the config 
        }
    }
}

public Action Command_ReloadConfig(int iClient, int args)
{
	LoadConfig();
	PrintToChat(iClient, " \x02[Shop] \x01Quizz Config file reloaded succesfully");
	return Plugin_Handled;
}
