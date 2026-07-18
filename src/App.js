import "./App.css";
import React from "react";
import "bootstrap/dist/css/bootstrap.min.css";
import DropdownButton from 'react-bootstrap/DropdownButton';
import Dropdown from 'react-bootstrap/Dropdown';
import { useData, useUserState, signInWithG, signOutOfG } from "./utilities/firebase.js";
import { FoodList, Expired, notify } from "./food";
import { AddButton } from "./form";
import Phase2Dashboard from "./components/Phase2Dashboard";
import {
  MainLayout,
  Header,
  H1,
  H2,
  Content,
  UserName,
} from "./styles/PantryStyles.js";
import { ToastContainer, toast, Slide } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';
import { useState, useEffect } from 'react';

const SignInButton = () => (
  <button className="btn" style = {{ outerHeight: 10}}
    onClick={() => signInWithG()}>
    Sign In
  </button>

);

const SignOutButton = ({ cuser, foods }) => {
  useEffect(() => { notify(foods) }, [foods]);
  return (<>
    <p className="email">
      {window.innerWidth > 800 ? cuser : null}
      <button className="btn" id="out" style={{ width: 120, margin: 10 }}
        onClick={() => signOutOfG()}>
        Sign Out
      </button>
    </p>
  </>
  )
};

const currUser = (user) => {
  if (user) {
    return "/users/" + user.uid + "/";
  }
  return "/";
}


export const App = () => {

  const user = useUserState();
  const [entry, setEntry] = useState();
  const [userKitchen, loading, error] = useData(currUser(user));
  const [sorting, setSorting] = useState('all')
  var matched = {};

  if (error) return <h1>{error}</h1>;
  if (loading) return <h1>Loading the data...</h1>;
  

  const mSearchCriteria = (user_kitchen) => {
    if (user_kitchen) {
     // 
      if (entry) {
        for (const [key, value] of Object.entries(user_kitchen.foods)) {
          switch (sorting) {
            case 'all':
              if (value.name.toLowerCase().includes(entry.toLowerCase())) {
                matched[key] = value;
              }
            case 'expired':
              if (value.name.toLowerCase().includes(entry.toLowerCase()) && Expired(value.expDate) == 0) {
                matched[key] = value;
              }
              continue;
            case 'expiring soon':
              if (value.name.toLowerCase().includes(entry.toLowerCase()) && Expired(value.expDate) == 1) {
                matched[key] = value;
              }
              continue;
            case 'good condition':
              if (value.name.toLowerCase().includes(entry.toLowerCase()) && Expired(value.expDate) == 2) {
                matched[key] = value;
              }
              continue;
          }
        }
      } else {
        //console.log(typeof user_kitchen.foods);
        if (typeof user_kitchen.foods === 'undefined') return window.location.reload(true);
        for (const [key, value] of Object.entries(user_kitchen.foods)) {
          switch (sorting) {
            case 'all':
              return user_kitchen.foods;
            case 'expired':
              if (Expired(value.expDate) == 0) {
                matched[key] = value;
              }
              continue;
            case 'expiring soon':
              if (Expired(value.expDate) == 1) {
                matched[key] = value;
              }
              continue;
            case 'good condition':
              if (Expired(value.expDate) == 2) {
                matched[key] = value;
              }
              continue;
          }
        }
      }

      return matched;
    }
    return "";
  };

  if (user) {
    if (userKitchen) {
      //console.log("USER KITCHEN FOODS ---> " + userKitchen.foods)
      matched = mSearchCriteria(userKitchen);
    }
  }


  const handleSelect = (e) => {

    console.log(`CLICKED ${e}`);
    if (e === "option-1") {
      setSorting('expired')
    } else if (e === "option-2") {
      setSorting("expiring soon")
    } else if (e === "option-3") {
      setSorting("good condition")
    } else {
      setSorting("all");
    }
  }

  return (
    <>
      <ToastContainer transition={Slide} />
      <MainLayout>
        <Header>
          <H1>My Kitchen</H1>
          <div className="signInBtn">

            {user ? <SignOutButton cuser={user.email} foods={userKitchen ? userKitchen.foods : null} />
              : <SignInButton />}

          </div>

        </Header>
        <Content>
          {user ?

            <div className= {"content-top"}>
              <input
                className="search-field"
                type="text"
                placeholder="Search..."
                value={entry}
                onChange={(e) => { setEntry(e.target.value) }} />

              <DropdownButton
                title={sorting}
                id="dropdown-menu-align-right"
                onSelect={handleSelect}>
                <Dropdown.Item eventKey="option-1">expired</Dropdown.Item>
                <Dropdown.Item eventKey="option-2">expiring soon</Dropdown.Item>
                <Dropdown.Item eventKey="option-3">good condition</Dropdown.Item>
                <Dropdown.Item eventKey="option-4">all</Dropdown.Item>
              </DropdownButton>
              <AddButton />
            </div> : ""}
          {!user ? <H2>Sign In To Unlock Your Kitchen</H2> : null}
          {user ? <Phase2Dashboard /> : null}
          {user ? <FoodList foods={matched} /> : ""}
        </Content>
      </MainLayout>
    </>
  );

};
//<div> <button onClick={quickadd}className="btn">quick add</button><FoodList foods={matched} /></div>
export default App;
