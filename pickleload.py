import pickle 

data = {"key": "value"} # example data

with open('data.pkl', 'wb') as f:
  pickle.dump(data, f)
